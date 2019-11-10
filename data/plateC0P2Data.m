% rectangular plate in tension


controlPts=[0 0; 0.25 0;0.5 0; 0.75 0; 1 0;
            0 0.25; 0.25 0.25;0.5 0.25; 0.75 0.25; 1 0.25;
            0 0.5; 0.25 0.5;0.5 0.5; 0.75 0.5; 1 0.5;
            0 0.75; 0.25 0.75;0.5 0.75; 0.75 0.75; 1 0.75;
            0 1; 0.25 1;0.5 1; 0.75 1; 1 1;
            ];

% knot vectors

uKnot = [0 0 0 0.5 0.5 1 1 1];
vKnot = [0 0 0 0.5 0.5 1 1 1];

weights = ones(1,25)';

p = 2;
q = 2;

noPtsX = 5;
noPtsY = 5;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% controlPts=[0 0; 0 0.5; 0 1;
%             0.5 0;0.5 0.5;0.5 1;
%             1 0; 1 0.5; 1 1];
% 
% 
% % knot vectors
% 
% uKnot = [0 0 0 1 1 1];
% vKnot = [0 0 0 1 1 1];
% 
% weights = ones(1,9)';
% 
% p = 2;
% q = 2;
% 
% noPtsX = 3;
% noPtsY = 3;
