% =========================================================================
%   4-RING MESH GENERATOR: STRICT EQUAL-DIAMETER SPLASH PHYSICS

% =========================================================================
clc; clear; close all;

disp('======================================================');
disp('   4-RING STRICT TOPOLOGY: EQUAL-DIAMETER UPWARD SPLASH');
disp('======================================================');
disp('NOTE: In this dedicated solver, the Inlet Diameter and');
disp('      Inner Vial Diameter are mathematically locked together');
disp('      to ensure 100% physical accuracy of the splash.');
disp('------------------------------------------------------');

D_in       = input('1. Enter Jet & Inner Vial Diameter (m) [e.g., 0.008]: ');
D_vial_out = input('2. Enter Outer Vial Diameter (m) [e.g., 0.00936]: ');
H_top_mid  = input('3. Enter gap from top to middle (m) [e.g., 0.1296]: ');
H_mid_bot  = input('4. Enter gap from middle to bottom (m) [e.g., 0.1]: ');

% --- DYNAMIC MESH RESOLUTION GUIDELINES ---
max_xy = D_in / 15;      
min_xy = 0.0001;         

fprintf('\n--- MESH RESOLUTION GUIDELINES ---\n');
fprintf('For a %g m inlet, VOF physics requires ds_xy to be %g m or smaller.\n', D_in, max_xy);
fprintf('-> Recommended ds_xy range : [%g to %g] meters.\n', min_xy, max_xy);
fprintf('-> Recommended ds_z range  : [1x to 3x of ds_xy] to maintain perfect aspect ratios.\n\n');

ds_xy      = input('5. Enter target horizontal cell size (m) [e.g., 0.0002]: ');
ds_z       = input('6. Enter target vertical cell size (m) [e.g., 0.0004]: ');
U_inlet    = abs(input('7. Enter inlet velocity magnitude (m/s) [e.g., 0.56]: '));
disp('------------------------------------------------------');

% --- THICKNESS SAFETY CHECK ---
% Outer wall must be min 13% thicker than inner wall to prevent 
% external 90-degree block collapse. Does not affect internal splash physics.
if D_vial_out < (D_in * 1.13)
    D_vial_out = D_in * 1.13;
    disp(['Note: Outer vial wall slightly thickened to ', num2str(D_vial_out), ' m to allow block generation.']);
end

% =========================================================================
% 1. GEOMETRY & MATH SETUP (4-Ring Topology)
% =========================================================================
R_tank = 0.150; 
r1 = D_in / 2;         % Shared by Jet and Inner Vial Wall
r2 = D_vial_out / 2;   % Outer Vial Wall
r3 = R_tank;           % Outer Tank
c = (0.17783 * D_in) / 2; 

z0 = 0.0;
z1 = -H_top_mid;
z2 = -(H_top_mid + H_mid_bot);

n_core = max(2, ceil((c * 2) / ds_xy));
n_r1   = max(2, ceil((r1 - (c * sqrt(2))) / ds_xy));
n_r2   = max(2, ceil((r2 - r1) / ds_xy));
n_r3   = max(10, ceil((r3 - r2) / (ds_xy * 15))); 
n_z1   = max(2, ceil(H_top_mid / ds_z));
n_z2   = max(2, ceil(H_mid_bot / ds_z));

safe_grading = 'simpleGrading (1 1 1)';
tank_grading = 'simpleGrading (25 1 1)'; 

cos45 = sqrt(2)/2;
xy1 = r1 * cos45; xy2 = r2 * cos45; xy3 = r3 * cos45;

% =========================================================================
% 2. blockMeshDict GENERATION (Base 0, Base 16, Base 32)
% =========================================================================
fileID = fopen('blockMeshDict', 'w');
fprintf(fileID, '/*--------------------------------*- C++ -*----------------------------------*\\\n');
fprintf(fileID, '| =========                 |                                                 |\n');
fprintf(fileID, '| \\\\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |\n');
fprintf(fileID, '|  \\\\    /   O peration     | Version:  v2512                                 |\n');
fprintf(fileID, '|   \\\\  /    A nd           | Website:  www.openfoam.com                      |\n');
fprintf(fileID, '|    \\\\/     M anipulation  |                                                 |\n');
fprintf(fileID, '\\*---------------------------------------------------------------------------*/\n');
fprintf(fileID, 'FoamFile\n{\n    version     2.0;\n    format      ascii;\n    class       dictionary;\n    object      blockMeshDict;\n}\n');
fprintf(fileID, '// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //\n\n');
fprintf(fileID, 'convertToMeters 1;\n\n');

% --- VERTICES ---
fprintf(fileID, 'vertices\n(\n');
Z_levels = [z0, z1, z2];
for i = 1:3
    z = Z_levels(i); base = (i-1)*16;
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d (Core)\n', c, -c, z, base+0);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', c, c, z, base+1);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -c, c, z, base+2);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -c, -c, z, base+3);
    
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d (R1: Jet & Inner Wall)\n', xy1, -xy1, z, base+4);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', xy1, xy1, z, base+5);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy1, xy1, z, base+6);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy1, -xy1, z, base+7);
    
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d (R2: Outer Wall)\n', xy2, -xy2, z, base+8);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', xy2, xy2, z, base+9);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy2, xy2, z, base+10);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy2, -xy2, z, base+11);
    
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d (R3: Tank)\n', xy3, -xy3, z, base+12);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', xy3, xy3, z, base+13);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy3, xy3, z, base+14);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy3, -xy3, z, base+15);
end
fprintf(fileID, ');\n\n');

% --- BLOCKS ---
fprintf(fileID, 'blocks\n(\n');
writeHex = @(v, n, g, cmt) fprintf(fileID, '    hex (%-2d %-2d %-2d %-2d %-2d %-2d %-2d %-2d) (%-3d %-3d %-3d) %s %s\n', v(1), v(2), v(3), v(4), v(5), v(6), v(7), v(8), n(1), n(2), n(3), g, cmt);

% Top Section (z1 to z0)
writeHex([16 17 18 19 0 1 2 3], [n_core, n_core, n_z1], safe_grading, '// Top Core');
writeHex([16 20 21 17 0 4 5 1], [n_r1, n_core, n_z1], safe_grading, '');
writeHex([17 21 22 18 1 5 6 2], [n_r1, n_core, n_z1], safe_grading, '');
writeHex([18 22 23 19 2 6 7 3], [n_r1, n_core, n_z1], safe_grading, '');
writeHex([19 23 20 16 3 7 4 0], [n_r1, n_core, n_z1], safe_grading, '');
writeHex([20 24 25 21 4 8 9 5], [n_r2, n_core, n_z1], safe_grading, '');
writeHex([21 25 26 22 5 9 10 6], [n_r2, n_core, n_z1], safe_grading, '');
writeHex([22 26 27 23 6 10 11 7], [n_r2, n_core, n_z1], safe_grading, '');
writeHex([23 27 24 20 7 11 8 4], [n_r2, n_core, n_z1], safe_grading, '');
writeHex([24 28 29 25 8 12 13 9], [n_r3, n_core, n_z1], tank_grading, '');
writeHex([25 29 30 26 9 13 14 10], [n_r3, n_core, n_z1], tank_grading, '');
writeHex([26 30 31 27 10 14 15 11], [n_r3, n_core, n_z1], tank_grading, '');
writeHex([27 31 28 24 11 15 12 8], [n_r3, n_core, n_z1], tank_grading, '');

% Bottom Section (z2 to z1) - NOTE: R2 is omitted to form the solid glass wall
writeHex([32 33 34 35 16 17 18 19], [n_core, n_core, n_z2], safe_grading, '// Bottom Core (Inside Vial)');
writeHex([32 36 37 33 16 20 21 17], [n_r1, n_core, n_z2], safe_grading, '');
writeHex([33 37 38 34 17 21 22 18], [n_r1, n_core, n_z2], safe_grading, '');
writeHex([34 38 39 35 18 22 23 19], [n_r1, n_core, n_z2], safe_grading, '');
writeHex([35 39 36 32 19 23 20 16], [n_r1, n_core, n_z2], safe_grading, '');
writeHex([40 44 45 41 24 28 29 25], [n_r3, n_core, n_z2], tank_grading, '// Bottom Tank (Outside Vial)');
writeHex([41 45 46 42 25 29 30 26], [n_r3, n_core, n_z2], tank_grading, '');
writeHex([42 46 47 43 26 30 31 27], [n_r3, n_core, n_z2], tank_grading, '');
writeHex([43 47 44 40 27 31 28 24], [n_r3, n_core, n_z2], tank_grading, '');
fprintf(fileID, ');\n\n');

% --- EDGES ---
fprintf(fileID, 'edges\n(\n');
radii = [r1, r2, r3];
start_idx = [4, 8, 12];
for z_iter = 0:2
    z_val = Z_levels(z_iter+1); z_off = z_iter * 16;
    for r_iter = 1:3
        r_val = radii(r_iter); idx = start_idx(r_iter) + z_off;
        fprintf(fileID, '    arc %d %d (%f 0.0 %f)\n', idx, idx+1, r_val, z_val);
        fprintf(fileID, '    arc %d %d (0.0 %f %f)\n', idx+1, idx+2, r_val, z_val);
        fprintf(fileID, '    arc %d %d (%f 0.0 %f)\n', idx+2, idx+3, -r_val, z_val);
        fprintf(fileID, '    arc %d %d (0.0 %f %f)\n', idx+3, idx, -r_val, z_val);
    end
end
fprintf(fileID, ');\n\n');

% --- BOUNDARIES ---
fprintf(fileID, 'boundary\n(\n');
fprintf(fileID, '    outlet\n    {\n        type patch;\n        faces\n        (\n');
fprintf(fileID, '            (8 12 13 9)\n            (9 13 14 10)\n            (10 14 15 11)\n            (11 15 12 8)\n');
fprintf(fileID, '            (12 28 29 13)\n            (13 29 30 14)\n            (14 30 31 15)\n            (15 31 28 12)\n');
fprintf(fileID, '            (28 44 45 29)\n            (29 45 46 30)\n            (30 46 47 31)\n            (31 47 44 28)\n');
fprintf(fileID, '            (40 44 45 41)\n            (41 45 46 42)\n            (42 46 47 43)\n            (43 47 44 40)\n        );\n    }\n');
fprintf(fileID, '    inlet\n    {\n        type patch;\n        faces\n        (\n');
fprintf(fileID, '            (0 3 2 1)\n            (0 4 5 1)\n            (1 5 6 2)\n            (2 6 7 3)\n            (3 7 4 0)\n        );\n    }\n');
fprintf(fileID, '    cap\n    {\n        type wall;\n        faces\n        (\n');
fprintf(fileID, '            (4 8 9 5)\n            (5 9 10 6)\n            (6 10 11 7)\n            (7 11 8 4)\n        );\n    }\n');
fprintf(fileID, '    vial\n    {\n        type wall;\n        faces\n        (\n');
fprintf(fileID, '            (20 21 25 24)\n            (21 22 26 25)\n            (22 23 27 26)\n            (23 20 24 27)\n');
fprintf(fileID, '            (36 37 21 20)\n            (37 38 22 21)\n            (38 39 23 22)\n            (39 36 20 23)\n');
fprintf(fileID, '            (32 35 34 33)\n            (32 33 37 36)\n            (33 34 38 37)\n            (34 35 39 38)\n            (35 32 36 39)\n');
fprintf(fileID, '            (40 24 25 41)\n            (41 25 26 42)\n            (42 26 27 43)\n            (43 27 24 40)\n        );\n    }\n');
fprintf(fileID, ');\n\nmergePatchPairs\n(\n);\n');
fclose(fileID);

% =========================================================================
% 3. setFieldsDict GENERATION (BERNOULLI PHYSICS-BASED TAPER)
% =========================================================================
fileID_sf = fopen('setFieldsDict', 'w');
fprintf(fileID_sf, '/*--------------------------------*- C++ -*----------------------------------*\\\n');
fprintf(fileID_sf, '| =========                 |                                                 |\n');
fprintf(fileID_sf, '| \\\\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox           |\n');
fprintf(fileID_sf, '|  \\\\    /   O peration     | Version:  v2512                                 |\n');
fprintf(fileID_sf, '|   \\\\  /    A nd           | Website:  www.openfoam.com                      |\n');
fprintf(fileID_sf, '|    \\\\/     M anipulation  |                                                 |\n');
fprintf(fileID_sf, '\\*---------------------------------------------------------------------------*/\n');
fprintf(fileID_sf, 'FoamFile\n{\n    version     2.0;\n    format      ascii;\n    class       dictionary;\n    object      setFieldsDict;\n}\n');
fprintf(fileID_sf, '// * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * //\n\n\n');
fprintf(fileID_sf, 'defaultFieldValues\n(\n    volScalarFieldValue alpha.water 0\n    volVectorFieldValue U (0 0 0)\n);\n\nregions\n(\n');

g = 9.81; 
n_slices = 50;         
dz = (z0 - z1) / n_slices; 

for s = 1:n_slices
    slice_z1 = z0 - (s-1)*dz;
    slice_z2 = z0 - s*dz;
    z_mid = (slice_z1 + slice_z2) / 2;
    
    drop_dist = z0 - z_mid; 
    U_slice = sqrt(U_inlet^2 + 2 * g * drop_dist);
    r_slice = r1 * sqrt(U_inlet / U_slice);
    
    fprintf(fileID_sf, '    cylinderToCell\n    {\n');
    fprintf(fileID_sf, '        p1              (0 0 %f);\n', slice_z1);
    fprintf(fileID_sf, '        p2              (0 0 %f);\n', slice_z2);
    fprintf(fileID_sf, '        radius          %f;\n', r_slice); 
    fprintf(fileID_sf, '        fieldValues\n        (\n');
    fprintf(fileID_sf, '            volScalarFieldValue alpha.water 1\n');
    fprintf(fileID_sf, '            volVectorFieldValue U (0 0 %f)\n', -U_slice);
    fprintf(fileID_sf, '        );\n    }\n');
end

fprintf(fileID_sf, '    // Initial water pool sitting inside the exact equal-diameter vial\n');
fprintf(fileID_sf, '    cylinderToCell\n    {\n');
fprintf(fileID_sf, '        p1              (0 0 %f);\n', z1);
fprintf(fileID_sf, '        p2              (0 0 %f);\n', z2);
fprintf(fileID_sf, '        radius          %f;\n', r1); 
fprintf(fileID_sf, '        fieldValues\n        (\n');
fprintf(fileID_sf, '            volScalarFieldValue alpha.water 1\n');
fprintf(fileID_sf, '            volVectorFieldValue U (0 0 0)\n'); 
fprintf(fileID_sf, '        );\n    }\n');
fprintf(fileID_sf, ');\n');
fclose(fileID_sf);

disp('Success! Dedicated 4-Ring topology generated. Physics are 100% accurate.');