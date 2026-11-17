% =========================================================================
%   Mesh & Field Generator - Smooth Grading + Tapered Jet (Physics-Based)
% =========================================================================
clc; clear; close all;

disp('======================================================');
disp('   Mesh & Field Generator - Smooth Grading + Tapered Jet');
disp('======================================================');
D_in       = input('1. Enter top inlet diameter (m) [e.g., 0.006]: ');
D_vial_in  = input('2. Enter inner vial diameter (m) [e.g., 0.008]: ');
D_vial_out = input('3. Enter outer vial diameter (m) [e.g., 0.00936]: ');
H_top_mid  = input('4. Enter gap from top to middle (m) [e.g., 0.0591]: ');
H_mid_bot  = input('5. Enter gap from middle to bottom (m) [e.g., 0.1]: ');

% --- DYNAMIC MESH RESOLUTION GUIDELINES ---
max_xy = D_in / 15;      
min_xy = 0.0001;         

fprintf('\n--- MESH RESOLUTION GUIDELINES ---\n');
fprintf('For a %g m inlet, VOF physics requires ds_xy to be %g m or smaller.\n', D_in, max_xy);
fprintf('-> Recommended ds_xy range : [%g to %g] meters.\n', min_xy, max_xy);
fprintf('-> Recommended ds_z range  : [1x to 3x of ds_xy] to maintain perfect aspect ratios.\n\n');

ds_xy      = input('6. Enter target horizontal cell size (m) [e.g., 0.0002]: ');
ds_z       = input('7. Enter target vertical cell size (m) [e.g., 0.0005]: ');
U_inlet    = abs(input('8. Enter inlet velocity magnitude (m/s) [e.g., 0.81]: '));
disp('------------------------------------------------------');

% --- CRITICAL GEOMETRY FIX FOR THIN O-GRID BLOCKS ---
min_ratio = 1.13; 
if D_vial_in < (D_in * min_ratio)
    D_vial_in_new = D_in * min_ratio;
    disp(['Note: To prevent OpenFOAM topological collapse, D_vial_in expanded from ', num2str(D_vial_in), ' to ', num2str(D_vial_in_new), ' m.']);
    D_vial_in = D_vial_in_new;
end
if D_vial_in >= D_vial_out
    error('Geometric Error: Inner vial diameter must be smaller than outer vial diameter.');
end

% =========================================================================
% 1. GEOMETRY & MATH SETUP
% =========================================================================
R_tank = 0.150; 
r1 = D_in / 2;
r2 = D_vial_in / 2;
r3 = D_vial_out / 2;
r4 = R_tank;
c = (0.17783 * D_in) / 2; 

z0 = 0.0;
z1 = -H_top_mid;
z2 = -(H_top_mid + H_mid_bot);

n_core = max(2, ceil((c * 2) / ds_xy));
n_r1   = max(2, ceil((r1 - (c * sqrt(2))) / ds_xy));
n_r2   = max(2, ceil((r2 - r1) / ds_xy));
n_r3   = max(2, ceil((r3 - r2) / ds_xy));
n_r4   = max(10, ceil((r4 - r3) / (ds_xy * 15))); 
n_z1   = max(2, ceil(H_top_mid / ds_z));
n_z2   = max(2, ceil(H_mid_bot / ds_z));

% --- RESTORED GRADING TRANSITIONS ---
safe_grading = 'simpleGrading (1 1 1)';
% Radially expands the outer tank cells by 25x from the vial wall to the edge
tank_grading = 'simpleGrading (25 1 1)'; 

cos45 = sqrt(2)/2;
xy1 = r1 * cos45; xy2 = r2 * cos45; xy3 = r3 * cos45; xy4 = r4 * cos45;

% =========================================================================
% 2. blockMeshDict GENERATION
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
    z = Z_levels(i); base = (i-1)*20;
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d (Core)\n', c, -c, z, base+0);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', c, c, z, base+1);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -c, c, z, base+2);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -c, -c, z, base+3);
    
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d (Ring 1)\n', xy1, -xy1, z, base+4);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', xy1, xy1, z, base+5);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy1, xy1, z, base+6);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy1, -xy1, z, base+7);
    
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d (Ring 2)\n', xy2, -xy2, z, base+8);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', xy2, xy2, z, base+9);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy2, xy2, z, base+10);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy2, -xy2, z, base+11);
    
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d (Ring 3)\n', xy3, -xy3, z, base+12);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', xy3, xy3, z, base+13);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy3, xy3, z, base+14);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy3, -xy3, z, base+15);
    
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d (Ring 4)\n', xy4, -xy4, z, base+16);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', xy4, xy4, z, base+17);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy4, xy4, z, base+18);
    fprintf(fileID, '    ( %9.6f  %9.6f  %9.6f ) // %-2d\n', -xy4, -xy4, z, base+19);
end
fprintf(fileID, ');\n\n');

% --- BLOCKS ---
fprintf(fileID, 'blocks\n(\n');
writeHex = @(v, n, g, cmt) fprintf(fileID, '    hex (%-2d %-2d %-2d %-2d %-2d %-2d %-2d %-2d) (%-3d %-3d %-3d) %s %s\n', v(1), v(2), v(3), v(4), v(5), v(6), v(7), v(8), n(1), n(2), n(3), g, cmt);

% Top Section (z1 to z0)
writeHex([20 21 22 23 0 1 2 3], [n_core, n_core, n_z1], safe_grading, '// Top Core');
writeHex([20 24 25 21 0 4 5 1], [n_r1, n_core, n_z1], safe_grading, '');
writeHex([21 25 26 22 1 5 6 2], [n_r1, n_core, n_z1], safe_grading, '');
writeHex([22 26 27 23 2 6 7 3], [n_r1, n_core, n_z1], safe_grading, '');
writeHex([23 27 24 20 3 7 4 0], [n_r1, n_core, n_z1], safe_grading, '');
writeHex([24 28 29 25 4 8 9 5], [n_r2, n_core, n_z1], safe_grading, '');
writeHex([25 29 30 26 5 9 10 6], [n_r2, n_core, n_z1], safe_grading, '');
writeHex([26 30 31 27 6 10 11 7], [n_r2, n_core, n_z1], safe_grading, '');
writeHex([27 31 28 24 7 11 8 4], [n_r2, n_core, n_z1], safe_grading, '');
writeHex([28 32 33 29 8 12 13 9], [n_r3, n_core, n_z1], safe_grading, '');
writeHex([29 33 34 30 9 13 14 10], [n_r3, n_core, n_z1], safe_grading, '');
writeHex([30 34 35 31 10 14 15 11], [n_r3, n_core, n_z1], safe_grading, '');
writeHex([31 35 32 28 11 15 12 8], [n_r3, n_core, n_z1], safe_grading, '');
writeHex([32 36 37 33 12 16 17 13], [n_r4, n_core, n_z1], tank_grading, '');
writeHex([33 37 38 34 13 17 18 14], [n_r4, n_core, n_z1], tank_grading, '');
writeHex([34 38 39 35 14 18 19 15], [n_r4, n_core, n_z1], tank_grading, '');
writeHex([35 39 36 32 15 19 16 12], [n_r4, n_core, n_z1], tank_grading, '');

% Bottom Section (z2 to z1)
writeHex([40 41 42 43 20 21 22 23], [n_core, n_core, n_z2], safe_grading, '// Bottom Core');
writeHex([40 44 45 41 20 24 25 21], [n_r1, n_core, n_z2], safe_grading, '');
writeHex([41 45 46 42 21 25 26 22], [n_r1, n_core, n_z2], safe_grading, '');
writeHex([42 46 47 43 22 26 27 23], [n_r1, n_core, n_z2], safe_grading, '');
writeHex([43 47 44 40 23 27 24 20], [n_r1, n_core, n_z2], safe_grading, '');
writeHex([44 48 49 45 24 28 29 25], [n_r2, n_core, n_z2], safe_grading, '');
writeHex([45 49 50 46 25 29 30 26], [n_r2, n_core, n_z2], safe_grading, '');
writeHex([46 50 51 47 26 30 31 27], [n_r2, n_core, n_z2], safe_grading, '');
writeHex([47 51 48 44 27 31 28 24], [n_r2, n_core, n_z2], safe_grading, '');
% Vial wall excluded
writeHex([52 56 57 53 32 36 37 33], [n_r4, n_core, n_z2], tank_grading, '');
writeHex([53 57 58 54 33 37 38 34], [n_r4, n_core, n_z2], tank_grading, '');
writeHex([54 58 59 55 34 38 39 35], [n_r4, n_core, n_z2], tank_grading, '');
writeHex([55 59 56 52 35 39 36 32], [n_r4, n_core, n_z2], tank_grading, '');
fprintf(fileID, ');\n\n');

% --- EDGES ---
fprintf(fileID, 'edges\n(\n');
radii = [r1, r2, r3, r4];
start_idx = [4, 8, 12, 16];
for z_iter = 0:2
    z_val = Z_levels(z_iter+1); z_off = z_iter * 20;
    for r_iter = 1:4
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
fprintf(fileID, '            (16 36 37 17)\n            (17 37 38 18)\n            (18 38 39 19)\n            (19 39 36 16)\n');
fprintf(fileID, '            (36 56 57 37)\n            (37 57 58 38)\n            (38 58 59 39)\n            (39 59 56 36)\n');
fprintf(fileID, '            (52 56 57 53)\n            (53 57 58 54)\n            (54 58 59 55)\n            (55 59 56 52)\n        );\n    }\n');
fprintf(fileID, '    inlet\n    {\n        type patch;\n        faces\n        (\n');
fprintf(fileID, '            (0 3 2 1)\n            (0 4 5 1)\n            (1 5 6 2)\n            (2 6 7 3)\n            (3 7 4 0)\n        );\n    }\n');
fprintf(fileID, '    cap\n    {\n        type wall;\n        faces\n        (\n');
fprintf(fileID, '            (4 8 9 5)\n            (5 9 10 6)\n            (6 10 11 7)\n            (7 11 8 4)\n');
fprintf(fileID, '            (8 12 13 9)\n            (9 13 14 10)\n            (10 14 15 11)\n            (11 15 12 8)\n');
fprintf(fileID, '            (12 16 17 13)\n            (13 17 18 14)\n            (14 18 19 15)\n            (15 19 16 12)\n        );\n    }\n');
fprintf(fileID, '    vial\n    {\n        type wall;\n        faces\n        (\n');
fprintf(fileID, '            (40 43 42 41)\n            (40 44 45 41)\n            (41 45 46 42)\n            (42 46 47 43)\n            (43 47 44 40)\n');
fprintf(fileID, '            (44 48 49 45)\n            (45 49 50 46)\n            (46 50 51 47)\n            (47 51 48 44)\n');
fprintf(fileID, '            (28 48 49 29)\n            (29 49 50 30)\n            (30 50 51 31)\n            (31 51 48 28)\n');
fprintf(fileID, '            (32 52 53 33)\n            (33 53 54 34)\n            (34 54 55 35)\n            (35 55 52 32)\n');
fprintf(fileID, '            (28 32 33 29)\n            (29 33 34 30)\n            (30 34 35 31)\n            (31 35 32 28)\n        );\n    }\n');
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

fprintf(fileID_sf, '    // Initial water pool sitting inside the vial\n');
fprintf(fileID_sf, '    cylinderToCell\n    {\n');
fprintf(fileID_sf, '        p1              (0 0 %f);\n', z1);
fprintf(fileID_sf, '        p2              (0 0 %f);\n', z2);
fprintf(fileID_sf, '        radius          %f;\n', r2); 
fprintf(fileID_sf, '        fieldValues\n        (\n');
fprintf(fileID_sf, '            volScalarFieldValue alpha.water 1\n');
fprintf(fileID_sf, '            volVectorFieldValue U (0 0 0)\n'); 
fprintf(fileID_sf, '        );\n    }\n');
fprintf(fileID_sf, ');\n');
fclose(fileID_sf);

disp('Success! Both dictionaries generated safely.');