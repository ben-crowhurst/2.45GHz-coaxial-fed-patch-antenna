function simulation(patch)
    addpath('~/opt/openEMS/share/CSXCAD/matlab')

    physical_constants;
    MM = 1e-3; % Millimeters (mm).

    feed.pos = patch.feed.y;
    feed.width = patch.feed.width;
    feed.R = patch.feed.impedance;

    substrate.cells = 8;
    substrate.width = patch.dielectric.width;
    substrate.length = patch.dielectric.length;
    substrate.thickness = patch.dielectric.height;
    substrate.epsR = patch.dielectric.effective_permittivity;
    % LaTex: \varkappa = \tan\delta2\pi f_r\varepsilon_0\varepsilon_{reff}
    substrate.kappa = patch.dielectric.loss_tangent * 2 * pi * patch.resonant_frequency * EPS0 * substrate.epsR;

    % Setup FDTD parameter.
    max_timesteps = 30000;
    min_decrement = 1e-5; % equivalent to -50 dB.
    f0 = patch.resonant_frequency;
    fc = 1e9; % 20 dB corner frequency (in this case 0 Hz - 3e9 Hz).
    FDTD = InitFDTD('NrTS', max_timesteps, 'EndCriteria', min_decrement);
    FDTD = SetGaussExcite(FDTD, f0, fc);
    BC = {'MUR' 'MUR' 'MUR' 'MUR' 'MUR' 'MUR'};

    FDTD = SetBoundaryCond(FDTD, BC);

    % Setup mesh.
    max_res = C0 / (f0 + fc) / MM / 20;
    SimBox = [100 100 25];
    mesh.x = [-SimBox(1) / 2 SimBox(1) / 2 -substrate.length / 2 substrate.length / 2 feed.pos];
    mesh.x = [mesh.x -patch.length / 2 - max_res / 2 * 0.66 -patch.length / 2 + max_res / 2 * 0.33 patch.length / 2 + max_res / 2 * 0.66 patch.length / 2 - max_res / 2 * 0.33];
    mesh.x = SmoothMeshLines(mesh.x, max_res, 1.4);

    mesh.y = [-SimBox(2) / 2 SimBox(2) / 2 -substrate.width / 2 substrate.width / 2 -feed.width / 2 feed.width / 2];
    mesh.y = [mesh.y -patch.width / 2 - max_res / 2 * 0.66 -patch.width / 2 + max_res / 2 * 0.33 patch.width / 2 + max_res / 2 * 0.66 patch.width / 2 - max_res / 2 * 0.33];
    mesh.y = SmoothMeshLines(mesh.y, max_res, 1.4);

    mesh.z = [-SimBox(3) / 2 linspace(0, substrate.thickness, substrate.cells) SimBox(3)];
    mesh.z = SmoothMeshLines(mesh.z, max_res, 1.4);
    mesh = AddPML(mesh, [8 8 8 8 8 8]);

    CSX = InitCSX();
    CSX = DefineRectGrid(CSX, MM, mesh);

    % Create patch (PEC).
    CSX = AddMetal(CSX, 'patch');
    start = [-patch.length / 2 -patch.width / 2 substrate.thickness];
    stop = [patch.length / 2 patch.width / 2 substrate.thickness];
    CSX = AddBox(CSX, 'patch', 10, start, stop);

    % Create substrate.
    CSX = AddMaterial(CSX, 'substrate');
    CSX = SetMaterialProperty(CSX, 'substrate', 'Epsilon', substrate.epsR, 'Kappa', substrate.kappa);
    start = [-substrate.length / 2 -substrate.width / 2 0];
    stop = [substrate.length / 2 substrate.width / 2 substrate.thickness];
    CSX = AddBox(CSX, 'substrate', 0, start, stop);

    % Create ground (same size as substrate).
    CSX = AddMetal(CSX, 'gnd');
    start(3) = 0;
    stop(3) = 0;
    CSX = AddBox(CSX, 'gnd', 10, start, stop);

    % Apply current source.
    start = [feed.pos - .1 -feed.width / 2 0];
    stop = [feed.pos + .1 +feed.width / 2 substrate.thickness];
    [CSX] = AddLumpedPort(CSX, 5, 1, feed.R, start, stop, [0 0 1], true);

    % Dump magnetic field over the patch antenna.
    CSX = AddDump(CSX, 'Ht_', 'DumpType', 1, 'DumpMode', 2);
    start = [-patch.length -patch.width substrate.thickness + 1];
    stop = [patch.length patch.width substrate.thickness + 1];
    CSX = AddBox(CSX, 'Ht_', 0, start, stop);

    % NF2FF calculations.
    [CSX nf2ff] = CreateNF2FFBox(CSX, 'nf2ff', -SimBox / 2, SimBox / 2);

    Sim_Path = 'tmp';
    Sim_CSX = 'simulation.xml';
    [status, message, messageid] = rmdir(Sim_Path, 's');
    [status, message, messageid] = mkdir(Sim_Path);
    WriteOpenEMS([Sim_Path '/' Sim_CSX], FDTD, CSX)

    % Run openEMS.
    openEMS_opts = '';
    RunOpenEMS(Sim_Path, Sim_CSX, openEMS_opts)

    % Postprocessing.
    freq = linspace(max([1e9, f0 - fc]), f0 + fc, 501);
    U = ReadUI({'port_ut1', 'et'}, 'tmp/', freq);
    I = ReadUI('port_it1', 'tmp/', freq);

    % Plot results.
    plot_time_domain_voltage(U)
    plot_feed_point_impedance(U, I, freq)

    s11 = plot_reflection_coefficient(U, I, freq);
    nf2ff = calculate_contour_plots(s11, U, I, Sim_Path, freq, nf2ff);

    plot_directivity(nf2ff)
    plot_phi(nf2ff)

    drawnow
    render()
endfunction

function plot_time_domain_voltage(U)
    figure

    [ax, h1, h2] = plotyy(U.TD{1}.t / 1e-9, U.TD{1}.val, U.TD{2}.t / 1e-9, U.TD{2}.val);

    set(h1, 'Linewidth', 2)
    set(h1, 'Color', [1 0 0])
    set(h2, 'Linewidth', 2)
    set(h2, 'Color', [0 0 0])

    grid on
    title('time domain voltage')
    xlabel('time t / ns')
    ylabel(ax(1), 'voltage ut1 / V')
    ylabel(ax(2), 'voltage et / V')

    y1 = ylim(ax(1));
    y2 = ylim(ax(2));
    ylim(ax(1), [-max(abs(y1)) max(abs(y1))])
    ylim(ax(2), [-max(abs(y2)) max(abs(y2))])
endfunction

function plot_feed_point_impedance(U, I, freq)
    figure

    Zin = U.FD{1}.val ./ I.FD{1}.val;
    plot(freq / 1e6, real(Zin), 'k-', 'Linewidth', 2)
    hold on
    grid on
    plot(freq / 1e6, imag(Zin), 'r--', 'Linewidth', 2)

    title('feed point impedance')
    xlabel('frequency f / MHz')
    ylabel('impedance Z_{in} / Ohm')
    legend('real', 'imag')
endfunction

function s11 = plot_reflection_coefficient(U, I, freq)
    figure

    uf_inc = 0.5 * (U.FD{1}.val + I.FD{1}.val * 50);
    if_inc = 0.5 * (I.FD{1}.val - U.FD{1}.val / 50);
    uf_ref = U.FD{1}.val - uf_inc;
    if_ref = I.FD{1}.val - if_inc;
    s11 = uf_ref ./ uf_inc;

    plot(freq / 1e6, 20 * log10(abs(s11)), 'k-', 'Linewidth', 2)
    grid on
    title('reflection coefficient S_{11}')
    xlabel('frequency f / MHz')
    ylabel('reflection coefficient |S_{11}|')
endfunction

function nf2ff = calculate_contour_plots(s11, U, I, Sim_Path, freq, nf2ff)
    P_in = 0.5 * U.FD{1}.val .* conj(I.FD{1}.val);

    f_res_ind = find(s11 == min(s11));
    f_res = freq(f_res_ind);

    thetaRange = (0:2:359) - 180;
    phiRange = [0 90];
    disp('calculating far field at phi=[0 90] deg...')
    nf2ff = CalcNF2FF(nf2ff, Sim_Path, f_res, thetaRange * pi / 180, phiRange * pi / 180);

    Dlog = 10 * log10(nf2ff.Dmax);

    disp(['radiated power: Prad = ' num2str(nf2ff.Prad) ' Watt'])
    disp(['directivity: Dmax = ' num2str(Dlog) ' dBi'])
    disp(['efficiency: nu_rad = ' num2str(100 * nf2ff.Prad ./ real(P_in(f_res_ind))) ' %'])
endfunction

function plot_directivity(nf2ff)
    figure
    polarFF(nf2ff, 'xaxis', 'theta', 'param', [1 2], 'normalize', 1)
endfunction

function plot_phi(nf2ff)
    figure
    plotFFdB(nf2ff, 'xaxis', 'theta', 'param', [1 2])
endfunction
