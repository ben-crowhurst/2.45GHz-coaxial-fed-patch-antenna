disp("/ Linearly Polarised Patch Antenna Designer /\n")
close all
clear
clc

addpath('~/opt/openEMS/share/openEMS/matlab')
physical_constants;

MM = 1e-3; % Millimeters (mm).
GHz = 10^9; % Gigahertz (Hz).

disp("Select dielectric substrate:")
disp("----------------------------")
disp("  a) FR-4")
disp("  b) RO4003C")
disp("  x) other")
selection = kbhit();

switch (selection)
    case 'a'
        patch.dielectric.permittivity = 4.4;
        patch.dielectric.loss_tangent = 1e-3;
    case 'b'
        patch.dielectric.permittivity = 3.8;
        patch.dielectric.loss_tangent = 1e-3;
    otherwise
        patch.dielectric.permittivity = input("Enter dielectric permittivity (F/m): ");
endswitch

if (!isnumeric(patch.dielectric.permittivity))
    error("Dielectric permittivity must be a numeric value!")
endif

if (any(selection == ['a', 'b']))
    printf("Dielectric permittivity (F/m): %d\n", patch.dielectric.permittivity)
endif

disp("\nSelect dielectric height (mm):")
disp("------------------------------");
disp("  a) 1.5mm")
disp("  b) 1.6mm")
disp("  x) other")
selection = kbhit();

switch (selection)
    case 'a' patch.dielectric.height = 1.5;
    case 'b' patch.dielectric.height = 1.6;
    otherwise
        patch.dielectric.height = input("Enter dielectric height (mm): ");
endswitch

if (!isnumeric(patch.dielectric.height))
    error("Dielectric height must be a numeric value!")
endif

if (any(selection == ['a', 'b']))
    printf("Dielectric height (mm): %d\n", patch.dielectric.height)
endif

disp("\nCoaxial probe input impedance (ohm):")
disp("------------------------------");
disp("  a) 50Ω")
disp("  b) 70Ω")
disp("  x) other")
selection = kbhit();

switch (selection)
    case 'a' patch.feed.impedance = 50;
    case 'b' patch.feed.impedance = 70;
    otherwise
        patch.feed.impedance = input("Enter input impedance (ohm): ");
endswitch

if (!isnumeric(patch.feed.impedance))
    error("Coaxial probe input impedance must be a numeric value!")
endif

if (any(selection == ['a', 'b']))
    printf("Coaxial probe input impedance (ohm): %d\n", patch.feed.impedance)
endif

% Coaxial feed positioning is the predominate influencing
% factor on input impedance at the 0-3GHz frequency range.
patch.feed.width = 2; % Fixed at 2mm.

patch.resonant_frequency = input("\nEnter resonant frequency (GHz): ") * GHz;

% LaTex: W = \frac{c_0}{2f_r} \sqrt{\frac{2}{\varepsilon_r+1}}
patch.width = ((C0 / (2 * patch.resonant_frequency)) * sqrt(2 / (patch.dielectric.permittivity + 1))) / MM;

% LaTex: \varepsilon_{reff} = \frac{\varepsilon_r+1}{2} + \frac{\varepsilon_r-1}{2} \left[1+12\frac{h}{W}\right]^{-\frac{1}{2}}
patch.dielectric.effective_permittivity = ...
    ((patch.dielectric.permittivity + 1) / 2) + ...
    ((patch.dielectric.permittivity - 1) / 2) * ...
    1 / sqrt(1 + 12 * (patch.dielectric.height / patch.width));

% Effective length due to fringing fields.
% Latex: L_{eff} = \frac{c_0}{2f_r\sqrt{\varepsilon_{reff}}}
Leff = C0 / ((2 * patch.resonant_frequency) * sqrt(patch.dielectric.effective_permittivity)) / MM;

% Fringing field reduction factor.
% LaTex: \Delta{L} = 0.412h \frac{(\varepsilon_{reff}+0.3)(\frac{W}{h}+0.264)}{(\varepsilon_{reff}-0.258)(\frac{W}{h}+0.8)}
dividend = (patch.dielectric.effective_permittivity + 0.3) * ((patch.width / patch.dielectric.height) + 0.264);
divisor = (patch.dielectric.effective_permittivity - 0.258) * ((patch.width / patch.dielectric.height) + 0.8);
deltaLength = 0.412 * patch.dielectric.height * (dividend / divisor);

% LaTex: L = L_{eff}-2\Delta{L}
patch.length = Leff - (2 * deltaLength);

% LaTex: L_g = 6h + L
patch.ground.length = patch.length + (6 * patch.dielectric.height);
patch.dielectric.length = patch.ground.length;

% LaTex: W_g = 6h + W
patch.ground.width = patch.width + (6 * patch.dielectric.height);
patch.dielectric.width = patch.ground.width;

% λ0 is the free-space wavelength.
L0 = C0 / patch.resonant_frequency;

% Parallel-plate radiator conductance.
% LaTex: G = \frac{\pi{W}}{\eta\lambda{_0}}\left[1-\frac{( \frac{2\pi f_r}{c0}  h)^2}{24}\right]
G = ((pi * (patch.width / 1000)) / (Z0 * L0)) * (1 - ((((2 * pi * patch.resonant_frequency) / C0) * (patch.dielectric.height / 1000))^2/24));

% Patch edge resistance.
% LaTex: R_e = \frac{1}{2G}
Re = 1 / (2 * G);

% LaTex: P_y = \frac{L}{\pi}\sin^{-1}\sqrt{\frac{Ri}{Re}}
patch.feed.y = (((patch.length / 1000) / pi) * asin(sqrt(patch.feed.impedance / Re)) * 1000);

% LaTex: P_x = \frac{W}{2}
patch.feed.x = patch.width / 2;

answer = yes_or_no("\nPlot antenna characteristics? ");

if (answer)
    simulation(patch)
endif

pkg load tablicious

function display_value = render(value)
    display_value = round(100 * value) / 100;
end

Parameter = {"Width"; "Length"; "Height"; "x-axis (W)"; "y-axis (L)"};
Patch = [render(patch.width); render(patch.length); 0; 0; 0];
Probe = [0; 0; 0; render(patch.feed.x); render(patch.feed.y)];
Ground = [render(patch.ground.width); render(patch.ground.length); 0; 0; 0];
Dielectric = [render(patch.dielectric.width); render(patch.dielectric.length); render(patch.dielectric.height); 0; 0];

prettyprint(table(Parameter, Patch, Dielectric, Ground, Probe))
disp("* values rendered to two decimals places.")
disp("* units in millimeters (mm).")

printf("\nPress return ↵ key to exit.");
pause;
printf("\n");
