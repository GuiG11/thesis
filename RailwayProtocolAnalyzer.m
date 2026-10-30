clear
clc
close all

% Ficheiros e parametros da comunicacao
folder = 'C:\UNI\Tese\Meu\Leituras UCC\03-jun-matlab';
files = dir(fullfile(folder, '*.mat'));
baud = 4800;
limiarA = 2.025;
limiarB = 2.055;
mostrarTramas = false;

fprintf('Encontrados %d ficheiros.\n', numel(files));

% Codigos identificados para as teclas (Canal B)
keyNames = {'ABAIXO', 'ACIMA', 'CONTRASTE', 'F1', 'F2', ...
            'F3', 'LUMINOSIDADE', 'OK'};
keyFrames = {'0010000011', '0110000011', '0111000011', ...
             '0010100011', '0100100011', '0000100011', ...
             '0011000011', '0010010011'};

grupoPortas = {'Avaria_portas.mat', 'Avaria_portas-0002.mat', ...
               'Avaria_portas-0003.mat'};
grupoBomba = {'Avaria_bomba_oleo.mat', 'Avaria_bomba_oleo_02.mat', ...
               'Avaria_bomba_oleo_03.mat'};

allFiles = struct('name', {}, 'bytes', {});
globalBytes = [];

%% Leitura dos ficheiros e descodificacao UART

for f = 1:numel(files)
    filename = files(f).name;
    S = load(fullfile(folder, filename));

    A = S.A(:)';
    B = S.B(:)';
    dt = S.Tinterval;
    Ns = (1 / baud) / dt;  % Amostras por bit, sem arredondar

    % Canal A
    logicA = A > limiarA;
    framesA = zeros(0, 10);
    startA = [];
    i = 2;

    while i <= numel(logicA) - round(10 * Ns)
        if logicA(i-1) == 1 && logicA(i) == 0
            pontos = round(i + (0.5:9.5) * Ns);
            bits = logicA(pontos);

            if bits(1) == 0 && bits(10) == 1
                framesA(end+1, :) = bits;
                startA(end+1) = i;
                i = round(i + 10 * Ns);
                continue
            end
        end
        i = i + 1;
    end

    % Canal B
    logicB = B > limiarB;
    framesB = zeros(0, 10);
    startB = [];
    i = 2;

    while i <= numel(logicB) - round(10 * Ns)
        if logicB(i-1) == 1 && logicB(i) == 0
            pontos = round(i + (0.5:9.5) * Ns);
            bits = logicB(pontos);

            if bits(1) == 0 && bits(10) == 1
                framesB(end+1, :) = bits;
                startB(end+1) = i;
                i = round(i + 10 * Ns);
                continue
            end
        end
        i = i + 1;
    end

    % Cada trama tem 1 start bit, 8 bits de dados e 1 stop bit.
    % Os bits de dados sao transmitidos do menos para o mais significativo.
    if isempty(framesA)
        bytes = [];
    else
        bytes = sum(framesA(:, 2:9) .* (2 .^ (0:7)), 2)';
    end

    allFiles(f).name = filename;
    allFiles(f).bytes = bytes;
    globalBytes = [globalBytes, bytes];

    % Identificacao de teclas
    fprintf('\nCanal B (%s)\n', filename);
    encontrouTecla = false;
    for n = 1:size(framesB, 1)
        trama = sprintf('%d', framesB(n, :));
        idx = find(strcmp(trama, keyFrames));
        for k = idx
            fprintf('Frame %3d -> %s\n', n, keyNames{k});
            encontrouTecla = true;
        end
    end
    if ~encontrouTecla
        fprintf('Nenhuma tecla conhecida encontrada.\n');
    end

    % Mostrar cada trama, se necessario
    if mostrarTramas
        fprintf('\n%s\n', filename);
        for n = 1:size(framesA, 1)
            value = bytes(n);
            if value >= 32 && value <= 126
                ascii = char(value);
            else
                ascii = '.';
            end
            fprintf('Frame %3d : %s -> 0x%02X (%c)\n', ...
                    n, sprintf('%d', framesA(n, :)), value, ascii);
        end
    end

    % Graficos dos dois canais e inicios de trama
    tA = (0:numel(A)-1) * dt;
    tB = (0:numel(B)-1) * dt;
    figure('Name', filename, 'NumberTitle', 'off', 'Color', 'w');

    subplot(2, 1, 1)
    plot(tA, A, 'b')
    hold on
    plot(tA(startA), A(startA), 'ro', 'MarkerFaceColor', 'r')
    grid on
    title(['Canal A - ' filename], 'Interpreter', 'none')
    xlabel('Tempo (s)')
    ylabel('Tensao (V)')

    subplot(2, 1, 2)
    plot(tB, B, 'r')
    hold on
    plot(tB(startB), B(startB), 'bo', 'MarkerFaceColor', 'b')
    grid on
    title(['Canal B - ' filename], 'Interpreter', 'none')
    xlabel('Tempo (s)')
    ylabel('Tensao (V)')
end

%% ANALISE - Frequencia dos bytes

fprintf('\n========== FREQUENCIA DOS BYTES ==========\n');
for f = 1:numel(allFiles)
    fprintf('\n%s\n', allFiles(f).name);
    bytes = allFiles(f).bytes;

    if isempty(bytes)
        fprintf('Sem bytes encontrados.\n');
        continue
    end

    counts = histcounts(bytes, -0.5:255.5);
    [sortedCounts, order] = sort(counts, 'descend');
    fprintf('Byte   ASCII   Ocorrencias\n');

    for n = 1:numel(order)
        if sortedCounts(n) == 0
            break
        end
        value = order(n) - 1;
        if value >= 32 && value <= 126
            ascii = char(value);
        else
            ascii = '.';
        end
        fprintf('0x%02X     %c      %d\n', value, ascii, sortedCounts(n));
    end
end

fprintf('\n========== FREQUENCIA GLOBAL ==========\n');
bytes = globalBytes;
if isempty(bytes)
    fprintf('Sem bytes encontrados.\n');
else
    counts = histcounts(bytes, -0.5:255.5);
    [sortedCounts, order] = sort(counts, 'descend');
    fprintf('Byte   ASCII   Ocorrencias\n');

    for n = 1:numel(order)
        if sortedCounts(n) == 0
            break
        end
        value = order(n) - 1;
        if value >= 32 && value <= 126
            ascii = char(value);
        else
            ascii = '.';
        end
        fprintf('0x%02X     %c      %d\n', value, ascii, sortedCounts(n));
    end
end

%% ANALISES - Sequencias repetidas de 2, 3 e 4 bytes

for nBytes = 2:4
    fprintf('\n========== SEQUENCIAS DE %d BYTES ==========\n', nBytes);
    seqMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    for f = 1:numel(allFiles)
        bytes = allFiles(f).bytes;
        for n = 1:(numel(bytes) - nBytes + 1)
            seq = strtrim(sprintf('%02X ', bytes(n:n+nBytes-1)));

            if isKey(seqMap, seq)
                info = seqMap(seq);
                info.count = info.count + 1;
                if ~ismember(f, info.files)
                    info.files(end+1) = f;
                end
            else
                info.count = 1;
                info.files = f;
            end
            seqMap(seq) = info;
        end
    end

    lista = keys(seqMap);
    counts = zeros(1, numel(lista));
    for n = 1:numel(lista)
        info = seqMap(lista{n});
        counts(n) = info.count;
    end

    [~, order] = sort(counts, 'descend');
    for n = 1:min(30, numel(order))
        idx = order(n);
        info = seqMap(lista{idx});
        fprintf('\n%s\n', lista{idx});
        fprintf('Ocorrencias: %d\n', info.count);
        fprintf('Ficheiros: ');
        fprintf('%d ', info.files);
        fprintf('\n');
    end
end

%% ANALISE - Periodicidade dos bytes

fprintf('\n========== PERIODICIDADE DOS BYTES ==========\n');
topResults = 15;

for f = 1:numel(allFiles)
    bytes = allFiles(f).bytes;
    results = [];

    for value = unique(bytes)
        pos = find(bytes == value);
        if numel(pos) < 3
            continue
        end

        distancias = diff(pos);
        results(end+1, :) = [value, numel(pos), ...
                             mean(distancias), std(distancias)];
    end

    fprintf('\n%s\n', allFiles(f).name);
    if isempty(results)
        fprintf('Sem ocorrencias suficientes.\n');
        continue
    end

    results = sortrows(results, 4);
    fprintf('Byte   ASCII   Ocorrencias   Dist.Media   Std\n');

    for n = 1:min(topResults, size(results, 1))
        value = results(n, 1);
        if value >= 32 && value <= 126
            ascii = char(value);
        else
            ascii = '.';
        end
        fprintf('0x%02X     %c        %4d        %8.2f    %8.2f\n', ...
                value, ascii, results(n, 2), results(n, 3), results(n, 4));
    end
end

%% Sequencias hexadecimais completas

fprintf('\n========== SEQUENCIAS HEXADECIMAIS ==========\n');
for f = 1:numel(allFiles)
    bytes = allFiles(f).bytes;
    fprintf('\n%s\n', allFiles(f).name);
    fprintf('Numero total de bytes: %d\n', numel(bytes));
    fprintf('0x%02X, ', bytes);
    fprintf('\n');
end

%% ANALISE - Leitura dos comandos do protocolo

fprintf('\n========== COMANDOS DO PROTOCOLO ==========\n');
for f = 1:numel(allFiles)
    fprintf('\n%s\n', allFiles(f).name);
    bytes = allFiles(f).bytes;
    i = 1;
    while i <= numel(bytes)
        if bytes(i) ~= 27
            if bytes(i) >= 32 && bytes(i) <= 126
                fprintf('%04d : ASCII "%c"\n', i, char(bytes(i)));
            else
                fprintf('%04d : DATA 0x%02X\n', i, bytes(i));
            end
            i = i + 1;
            continue
        end

        if i == numel(bytes)
            fprintf('%04d : ESC (fim do ficheiro)\n', i);
            break
        end

        cmd = char(bytes(i+1));
        switch cmd
            case {'S', 'X', 'R', 'E', 'a', 'u', 'm'}
                switch cmd
                    case 'S'
                        nArgs = 6;
                    case {'X', 'R'}
                        nArgs = 7;
                    case 'E'
                        nArgs = 4;
                    otherwise
                        nArgs = 2;
                end

                if i + 1 + nArgs <= numel(bytes)
                    args = char(bytes(i+2:i+1+nArgs));
                    if cmd == 'a'
                        if mod(bytes(i+3), 2) == 1
                            estado = 'ON';
                        else
                            estado = 'OFF';
                        end
                        fprintf('%04d : ESC a    [%c %c]  Highlight %s\n', ...
                                i, bytes(i+2), bytes(i+3), estado);
                    else
                        fprintf('%04d : ESC %s    [%s]\n', i, cmd, args);
                    end
                    i = i + 2 + nArgs;
                elseif any(cmd == 'SXR')
                    fprintf('%04d : ESC %s (incompleto)\n', i, cmd);
                    break
                else
                    fprintf('%04d : ESC %s\n', i, cmd);
                    i = i + 2;
                end

            case 'p'
                j = i + 2;
                while j <= numel(bytes) && bytes(j) >= 48 && bytes(j) <= 57
                    j = j + 1;
                end
                numeros = char(bytes(i+2:j-1));
                if j <= numel(bytes)
                    fprintf('%04d : ESC p    [%s] termina em "%c"\n', ...
                            i, numeros, char(bytes(j)));
                else
                    fprintf('%04d : ESC p    [%s]\n', i, numeros);
                end
                i = j;

            case {'@', 'A', 'B', 'C', 'D', 'F', 'H', 'h', 'i', 'k', 'l', 'w'}
                fprintf('%04d : ESC %s\n', i, cmd);
                i = i + 2;

            otherwise
                fprintf('%04d : ESC 0x%02X (%c)\n', i, bytes(i+1), cmd);
                i = i + 2;
        end
    end
end

%% ANALISE - Comparacao dos ficheiros

% Analisados os seguuintes comandos (em ASCII)
uniqueCommands = {'A', 'B', 'C', 'D', 'E', 'F', 'H', 'P', 'R', 'S', 'X', ...
                  'a', 'h', 'i', 'k', 'o', 's', 'u', 'w', '@'};

% Guardar comandos e argumentos encontrados
commandData = cell(numel(allFiles), 1);
for f = 1:numel(allFiles)
    bytes = allFiles(f).bytes;
    commands = {};
    arguments = {};

    for i = 1:(numel(bytes) - 1)
        if bytes(i) ~= 27
            continue
        end

        cmd = char(bytes(i+1));
        if ~ismember(cmd, uniqueCommands)
            continue
        end

        arg = '';
        j = i + 2;
        while j <= numel(bytes) && bytes(j) >= 32 && bytes(j) <= 126
            arg(end+1) = char(bytes(j));
            j = j + 1;
        end

        commands{end+1} = cmd;
        arguments{end+1} = arg;
    end
    commandData{f}.commands = commands;
    commandData{f}.arguments = arguments;
end

% Presenca dos comandos em cada ficheiro
fprintf('\n========== PRESENCA DE COMANDOS ==========\n');
presenceMatrix = zeros(numel(allFiles), numel(uniqueCommands));

for f = 1:numel(allFiles)
    for c = 1:numel(uniqueCommands)
        presenceMatrix(f, c) = any(strcmp( ...
            commandData{f}.commands, uniqueCommands{c}));
    end
end

fprintf('%-32s', 'Ficheiro');
for c = 1:numel(uniqueCommands)
    fprintf('%4s', uniqueCommands{c});
end
fprintf('\n');

for f = 1:numel(allFiles)
    fprintf('%-32s', allFiles(f).name);
    fprintf('%4d', presenceMatrix(f, :));
    fprintf('\n');
end

% Argumentos encontrados por comando
fprintf('\n========== ARGUMENTOS DOS COMANDOS ==========\n');
for c = 1:numel(uniqueCommands)
    cmd = uniqueCommands{c};
    allArgs = {};

    for f = 1:numel(allFiles)
        dados = commandData{f};
        idx = strcmp(dados.commands, cmd);
        allArgs = [allArgs, dados.arguments(idx)];
    end

    allArgs = unique(allArgs(~cellfun('isempty', allArgs)));
    if ~isempty(allArgs)
        fprintf('\nESC %s:\n', cmd);
        fprintf('    %s\n', allArgs{:});
    end
end

% Argumentos comuns nas avarias de portas
fprintf('\n========== ARGUMENTOS COMUNS: PORTAS ==========\n');
nomes = {allFiles.name};
idxPortas = zeros(1, numel(grupoPortas));

for k = 1:numel(grupoPortas)
    idx = find(strcmp(nomes, grupoPortas{k}), 1);
    if isempty(idx)
        fprintf('Ficheiro em falta: %s\n', grupoPortas{k});
        idxPortas = [];
        break
    end
    idxPortas(k) = idx;
end

if ~isempty(idxPortas)
    for c = 1:numel(uniqueCommands)
        cmd = uniqueCommands{c};
        comuns = {};

        for k = 1:numel(idxPortas)
            dados = commandData{idxPortas(k)};
            args = dados.arguments(strcmp(dados.commands, cmd));
            args = unique(args(~cellfun('isempty', args)));

            if k == 1
                comuns = args;
            else
                comuns = intersect(comuns, args, 'stable');
            end
        end

        if ~isempty(comuns)
            fprintf('ESC %s:\n', cmd);
            fprintf('    %s\n', comuns{:});
        end
    end
end

% Argumentos comuns nas avarias da bomba
fprintf('\n========== ARGUMENTOS COMUNS: BOMBA ==========\n');
idxBomba = zeros(1, numel(grupoBomba));

for k = 1:numel(grupoBomba)
    idx = find(strcmp(nomes, grupoBomba{k}), 1);
    if isempty(idx)
        fprintf('Ficheiro em falta: %s\n', grupoBomba{k});
        idxBomba = [];
        break
    end
    idxBomba(k) = idx;
end

if ~isempty(idxBomba)
    for c = 1:numel(uniqueCommands)
        cmd = uniqueCommands{c};
        comuns = {};

        for k = 1:numel(idxBomba)
            dados = commandData{idxBomba(k)};
            args = dados.arguments(strcmp(dados.commands, cmd));
            args = unique(args(~cellfun('isempty', args)));

            if k == 1
                comuns = args;
            else
                comuns = intersect(comuns, args, 'stable');
            end
        end

        if ~isempty(comuns)
            fprintf('ESC %s:\n', cmd);
            fprintf('    %s\n', comuns{:});
        end
    end
end

% Sequencias de comandos
for nCmd = 2:3
    fprintf('\n========== SEQUENCIAS DE %d COMANDOS ==========\n', nCmd);
    seqData = cell(numel(allFiles), 1);

    for f = 1:numel(allFiles)
        cmds = commandData{f}.commands;
        seqs = {};
        for n = 1:(numel(cmds) - nCmd + 1)
            seqs{end+1} = strjoin(cmds(n:n+nCmd-1), ' -> ');
        end
        seqData{f} = unique(seqs);
    end

    comunsBomba = {};
    if ~isempty(idxBomba)
        for k = 1:numel(idxBomba)
            if k == 1
                comunsBomba = seqData{idxBomba(k)};
            else
                comunsBomba = intersect(comunsBomba, seqData{idxBomba(k)}, 'stable');
            end
        end
    end

    comunsPortas = {};
    if ~isempty(idxPortas)
        for k = 1:numel(idxPortas)
            if k == 1
                comunsPortas = seqData{idxPortas(k)};
            else
                comunsPortas = intersect(comunsPortas, seqData{idxPortas(k)}, 'stable');
            end
        end
    end

    if nCmd == 2
        fprintf('\nComuns as avarias da bomba:\n');
        fprintf('    %s\n', comunsBomba{:});
        fprintf('\nComuns as avarias de portas:\n');
        fprintf('    %s\n', comunsPortas{:});
    end

    soBomba = setdiff(comunsBomba, comunsPortas, 'stable');
    soPortas = setdiff(comunsPortas, comunsBomba, 'stable');

    fprintf('\nComuns a bomba e nao a portas:\n');
    fprintf('    %s\n', soBomba{:});
    fprintf('\nComuns a portas e nao a bomba:\n');
    fprintf('    %s\n', soPortas{:});
end
