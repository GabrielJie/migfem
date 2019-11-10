%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Isogeometric analysis for Kirchoff-Love shell problems.
%
%
% The displacment vectors are stored as
% [ux1 uy1 uz1 ux2 uy2 uz2 ....]
%
% Geometrically nonlinear formulation.
%
% Vinh Phu Nguyen, 19 March 2013
% Cardiff University
% nvinhphu@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

addpath ../fem_util/
addpath ../C_files/
addpath ../data/
addpath ../meshing/
addpath ../post-processing/
addpath ../fem-functions/
addpath ../meshing/
addpath ../integration/
addpath ../nurbs-util/
addpath ../nurbs-geopdes/inst/
addpath ../geometric-nonlinear/

clc
clear all

global p q element index elRangeU elRangeV elRangeW uKnot vKnot wKnot nElmLK...
    weights noCtrPts noDofs Ke0 controlPts W GP noPtsX noPtsY noPtsZ nu E ...
    memStiff benStiff

global shapes  gradsx  gradse  grads2x  grads2e  grads2xe


tic;

vtuFileName = 'halfCylinderShell';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%%  CAD input: control points and knot vectors
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

halfGNLCylinderShellData

% constitutive matrix

memStiff = E*t/(1-nu^2);
benStiff = E*t^3/12/(1-nu^2);

% force, no of steps

F           = 2000.;
noSteps     = 80;
deltaF      = F/noSteps;

%% Dirichlet BCs (symmetry conditions)
%   z
%   | 
% (D)------- (C)
%   |      |
%   |    L | 
%   |  R   | 
% (A)------- (B) --->x 
%
% free: AB: 
% Symmetry conditions: AD
% BC: hinged  
% CD: fully clamped

EPS = 1e-14;

% boundary nodes
nodesOnAB  = find(abs(controlPts(:,3))<EPS)'; 
nodesOnCD  = find(abs(controlPts(:,3)-L)<EPS)';
nodesOnCB  = find(abs(controlPts(:,2))<EPS)';
nodesOnAD  = find(abs(controlPts(:,1))<EPS)';

% nodes (control points) right next to boundary nodes
nextToABNodes = noPtsX+1:2*noPtsX;
nextToADNodes = noPtsX-1:noPtsX:noPtsX*(noPtsY)-1;
nextToCDNodes = noPtsX*(noPtsY-2)+1:noPtsX*(noPtsY-1);
nextToBCNodes = 2:noPtsX:noPtsX*(noPtsY-1)+2;

xConsNodes = unique([nodesOnCD nodesOnAD nextToCDNodes ]);
yConsNodes = unique([nodesOnCD nodesOnCB nextToCDNodes]);                
zConsNodes = unique([nodesOnCD nextToCDNodes ]);

% find nodes for recording disp/loads (A,B,C)

forcedNode = intersect(nodesOnAB,nodesOnAD);

nodeA = forcedNode;
recordADof = nodeA*3-1;    % y-direction displacement

recordDisp = zeros(1,noSteps);
recordForc = zeros(1,noSteps);

% build connectivity ...

generateIGA2DMesh

noCtrPts       = noPtsX   * noPtsY;
noDofs         = noCtrPts * 3;   % three displacement dofs per node

% initialization,

u    = zeros(noDofs,1);        % displacement vector
fext = zeros(noDofs,1);        % external force vector
%fint = zeros(noDofs,1);        % internal force vector


% essential boundary conditions

udofs      = 3*xConsNodes-2;
vdofs      = 3*yConsNodes-1;
wdofs      = 3*zConsNodes-0;

uFixed = zeros(size(xConsNodes));
vFixed = zeros(size(yConsNodes));
wFixed = zeros(size(zConsNodes));


% build visualization mesh only once

buildVMeshShell;
%% fast assembly using the triple sparse matrix

nElNod = size(element,2);
nElDof = nElNod*3;
Ke0    = zeros(nElDof,nElDof); % element Ke

%% Bezier extraction operators
% and pre-compute shape functions and derivatives

[C,Cxi,Cet]  = bezierExtraction2D(uKnot,vKnot,p,q);

% Pre-compute Bernstein basis and derivatives for ONE Bezier element

[W,GP] = gaussianQuad2DNURBS(p+1,q+1);

noBasis = (p+1)*(q+1);
noGpEle = (p+1)*(q+1);

eshapes  = zeros(noGpEle,noBasis);
egrads1  = zeros(noGpEle,noBasis,2);
egrads2  = zeros(noGpEle,noBasis,3);

for gp=1:size(W,1)
    [eshapes(gp,:) egrads1(gp,:,:) egrads2(gp,:,:)] = ...
        getShapeGrad2Bernstein2D(p,q,GP(gp,1),GP(gp,2));
end

shapesE    = zeros(noGpEle,noBasis);
gradsxE    = zeros(noGpEle,noBasis);
gradseE    = zeros(noGpEle,noBasis);
grads2xE   = zeros(noGpEle,noBasis);
grads2eE   = zeros(noGpEle,noBasis);
grads2xeE  = zeros(noGpEle,noBasis);

for e=1:noElems
    sctr   = element(e,:);         % element scatter vector
    Ce     = C(:,:,e);             % element Bezier extraction operator
    we     = diag(weights(sctr));  % element weights
    Wb     = Ce'*weights(sctr);    % element Bezier weights
    
    % loop over Gauss points
    
    for gp=1:size(W,1)        
        %% Bernstein basis and 1s1 and 2nd derivatives at GP gp
        Be      = eshapes(gp,:)';
        dBe     = reshape(egrads1(gp,:,:),noBasis,2);
        dB2e    = reshape(egrads2(gp,:,:),noBasis,3);
        
        %% Bezier weight functions (denomenator of NURBS)
        wb         = dot(Be,Wb);            % Be(I)*Wb(I)
        dwbdxi(1)  = dot(dBe(:,1),Wb);      % Be(I)_{,xi} * Wb(I)
        dwbdxi(2)  = dot(dBe(:,2),Wb);      % Be(I)_{,et} * Wb(I)
        dwb2dxi(1) = dot(dB2e(:,1),Wb);     % Be(I)_{,xixi} * Wb(I)
        dwb2dxi(2) = dot(dB2e(:,2),Wb);     % Be(I)_{,etaeta} * Wb(I)
        dwb2dxi(3) = dot(dB2e(:,3),Wb);     % Be(I)_{,xieta} * Wb(I)
        
        %% Shape function and derivatives
        shapesE(gp,:)   = we*Ce*Be/wb;
        gradsxE(gp,:)   = we*Ce*(dBe(:,1)/wb-dwbdxi(1)*Be/(wb*wb));
        gradseE(gp,:)   = we*Ce*(dBe(:,2)/wb-dwbdxi(2)*Be/(wb*wb));
        
        grads2xE(gp,:)  = we*Ce*(dB2e(:,1)/wb-2*dBe(:,1)*dwbdxi(1)/(wb*wb) - ...
                                  Be*dwb2dxi(1)/(wb*wb) + 2*Be*(dwbdxi(1))^2/(wb^3));
                               
        grads2eE(gp,:)  = we*Ce*(dB2e(:,2)/wb-2*dBe(:,2)*dwbdxi(2)/(wb*wb) - ...
                                  Be*dwb2dxi(2)/(wb*wb) + 2*Be*(dwbdxi(2))^2/(wb^3));
                               
        grads2xeE(gp,:) = we*Ce*(dB2e(:,3)/wb - dBe(:,1)*dwbdxi(2)/(wb*wb) - dBe(:,2)*dwbdxi(1)/(wb*wb) - ...
                                  Be*dwb2dxi(3)/(wb*wb) + 2*Be*dwbdxi(1)*dwbdxi(2)/(wb^3));                               
    end
    
   shapes{e}   = shapesE;
   gradsx{e}   = gradsxE;
   gradse{e}   = gradseE;
   grads2x{e}  = grads2xE;
   grads2e{e}  = grads2eE;
   grads2xe{e} = grads2xeE;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%% PROCESSING
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


w     = 1e10;
penaltyStiffness = w*[1 -1;-1 1];

tol      = 1e-4;
iterMax  = 40;  % maximum number of Newton-Raphson iterations

for i = 1:noSteps
    
    disp ('=================================')
    disp (sprintf('   Load step %d',i));
    disp ('=================================')
    disp ('  NR iter : L2-norm residual')
    
    % compute the tangent and internal force
    
    [K,fint] = getTangentStiffnessMatrixThinShell (u);
    
    K= doConstraint2(K,nodesOnCB, nextToBCNodes,...
                       nodesOnAD, nextToADNodes, penaltyStiffness);
      
    fext(forcedNode*3-1) = fext(forcedNode*3-1) - 0.5*deltaF;
   
    % Newton-Raphson iterations
    error    = 1;
    iiter    = 0;
    
    while error > tol
        
        iiter    = iiter + 1;
        
        % solve for the displacement increment
        
        res      = fext-fint;
        [K,res]  = applyDirichletBCs3D(K,res,udofs,vdofs,wdofs,uFixed,vFixed,wFixed);
        deltaU   = K\res;
        
        % update displacements
        
        u = u + deltaU;
        
        [K,fint] = getTangentStiffnessMatrixThinShell(u);
        
        K = doConstraint2(K, nodesOnCB, nextToBCNodes,...
                             nodesOnAD, nextToADNodes, penaltyStiffness);
        
        if iiter == 1
            rnmax = 0.;
        end
        
        normdu = norm(deltaU);
        rnmax  = max(rnmax,normdu);
        error  = normdu/rnmax;
        
        disp (sprintf(' %s %i %s %5.4e %3.2f', 'Iter',iiter, ':', error, toc) );
        
        if iiter == iterMax
            error('Newton-Raphson iterations did not converge!');
        end
    end
    
    %% the step has been converged...
    
    recordDisp (1,i)  = u(recordADof);
    recordForc (1,i)  = fint(recordADof);
    
    % write to VTK files
    
    vtuFile = sprintf('../results/%s%d',vtuFileName,i);
    
    writeVTKShell (vtuFile,u,node,elementV);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%% POST-PROCESSING
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp([num2str(toc),'  POST-PROCESSING']);

%% Visualization using a Q4 visualization mesh

%% write a PVD file that collects all VTU files
% An example is given
% <VTKFile byte_order='LittleEndian' type='Collection' version='0.1'>
% <Collection>
% <DataSet file='cantilever8-0.vtu' groups='' part='0' timestep='0'/>
% <DataSet file='cantilever8-1.vtu' groups='' part='0' timestep='1'/>
% </Collection>
% </VTKFile>

pvdFile = fopen(strcat('../results/',vtuFileName,'.pvd'), 'wt');

fprintf(pvdFile,'<VTKFile byte_order="LittleEndian" type="Collection" version="0.1">\n');
fprintf(pvdFile,'<Collection>\n');

for i = 1:noSteps
    vtuFile = sprintf('%s%d%s',vtuFileName,i,'.vtu');
    fprintf(pvdFile,'<DataSet file=''%s'' groups='''' part=''0'' timestep=''%d''/>\n',vtuFile,i);
end

fprintf(pvdFile,'</Collection>\n');
fprintf(pvdFile,'</VTKFile>\n');

fclose(pvdFile);


%% plot the load-displacement curve

% refenrece solution from Sze et al, 2004
% Popular benchmark problems for geometric nonlinear analysis of shells

P= F*[0;0.05;0.1;0.125;0.15;0.175;0.20;0.225;0.25;0.275;0.3;0.325;0.35;0.40;0.45;0.5;0.55;...
       0.6;0.65;0.7;0.75;0.8;0.85;0.9;0.95;1];

wA = [ 0;5.421;16.1;22.195;27.657;32.7;37.582;42.633;48.537;56.355;66.41;79.81;94.669;113.704;124.751;132.653;138.92;...
    144.185;148.77;152.863;156.584;160.015;163.211;166.2;168.973;171.505]/100;


figure
hold on

plot(-recordDisp(1,:),2*recordForc(1,:),'rd-','LineWidth',1.4);
plot(wA,P,'bs','LineWidth',1.2);

xlabel('Vertical displacment (mm)');
ylabel('End force (N)');
legend('iga-uz','ref-uz','iga-ux','ref-ux')
%axis([0 8 0 0.27])

%% write the reference solution to a file 
% (disp, force) format

file = fopen('~/code/jive/bezier/halfCylinderShellRef.dat', 'wt');



for i=1:length(P)
   fprintf(file, '  %2.8f %2.8f', wA(i), P(i));
   fprintf(file, '\n');
end



