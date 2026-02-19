% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. ШЛЯХИ ---
baseDirectory = 'X:\EEGMAG\ab3';
eeglabDirectory = 'X:\eeglab2025.1.0\plugins';

% ВИПРАВЛЕНО: Прибрано "5.5" та зайві слеші всередині fullfile
dipfitPath = fullfile(eeglabDirectory, 'dipfit', 'standard_BEM'); 
templateChannelFilePath = fullfile(dipfitPath, 'elec', 'standard_1020.elc');
hdmFilePath = fullfile(dipfitPath, 'standard_vol.mat');
mriFilePath = fullfile(dipfitPath, 'standard_mri.mat');

amicafold = fullfile(baseDirectory, 'amicaResults');
if ~exist(amicafold, 'dir'), mkdir(amicafold); end

outputDirectory = fullfile(baseDirectory, 'Data_Procesed');
if ~exist(outputDirectory, 'dir'), mkdir(outputDirectory); end

% --- 2. ЗАПУСК EEGLAB ---
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% --- 3. ПОШУК ФАЙЛІВ ---
setFiles = dir(fullfile(baseDirectory, 'Data_Sinhronizovane', '*.set'));

if isempty(setFiles)
    error('Не знайдено файлів .set у папці Data_Sinhronizovane! Перевір шляхи.');
end

% --- 4. ЦИКЛ ОБРОБКИ ---
for i = 1:length(setFiles)

    loadName = setFiles(i).name;
    dataName = loadName(1:end-4);
    
    % === РОЗУМНА ПЕРЕВІРКА (RESUME) ===
    finalOutputFile = fullfile(outputDirectory, [dataName, '.set']);
    if exist(finalOutputFile, 'file')
        fprintf('Файл %s вже готовий. ПРОПУСКАЮ.\n', dataName);
        continue; 
    end
    % ==================================

    % Перевірка імені файлу
    validTags = ["New1", "New2", "New3", "New4", "Old1", "Old2", "tive", "Proective"];
    isValid = false;
    for tag = validTags
        if contains(dataName, tag)
            isValid = true; break;
        end
    end
    
    if ~isValid
        fprintf('Пропускаю (фільтр імені): %s\n', loadName);
        continue;
    end
    
    fprintf('=== Обробка: %s ===\n', loadName);
    
    % Завантаження
    EEG = pop_loadset('filename', loadName, 'filepath', setFiles(i).folder);
    
    % ВИДАЛЯЄМО EEG.event = []; - ТЕПЕР МИ БЕРЕЖЕМО ПОДІЇ!
    % Якщо ми їх видалимо, то втратимо синхронізацію після ASR.
    
    % --- ОЧИСТКА (ASR) ---
    originalEEG = EEG;
    
    EEG = pop_clean_rawdata(EEG, ...
        'FlatlineCriterion', 5, ...
        'ChannelCriterion', 0.87, ...
        'LineNoiseCriterion', 4, ... % Це прибирає 50 Гц замість CleanLineNoise
        'Highpass', [0.25 0.75], ...
        'BurstCriterion', 20, ...
        'WindowCriterion', 0.25, ...
        'Distance', 'Euclidian', ...
        'WindowCriterionTolerances', [-Inf 7], ...
        'fusechanrej', 1);
    
    % Інтерполяція
    EEG = pop_interp(EEG, originalEEG.chanlocs, 'spherical');
    
    % Re-referencing
    EEG.nbchan = EEG.nbchan+1;
    EEG.data(end+1,:) = zeros(1, EEG.pnts);
    EEG.chanlocs(1,EEG.nbchan).labels = 'initialReference';
    EEG = pop_reref(EEG, []);
    EEG = pop_select(EEG, 'nochannel', {'initialReference'});
    
    % --- ТУТ БУЛА ПОМИЛКА IMPORT EVENT ---
    % Я її прибрав. Події залишаються ті, що були у файлі, 
    % але ASR їх правильно посунув.
    
    % --- AMICA ---
    if isfield(EEG.etc, 'clean_channel_mask')
        dataRank = min([rank(double(EEG.data')) sum(EEG.etc.clean_channel_mask)]);
    else
        dataRank = rank(double(EEG.data'));
    end
    
    EEG_forICA = pop_resample(EEG, 100); 
    amicaOutDir = fullfile(amicafold, dataName);
    
    if ~exist(fullfile(amicaOutDir, 'W.fdt'), 'file')
        fprintf('  Запуск AMICA...\n');
        runamica15(EEG_forICA.data, 'num_chans', EEG.nbchan, 'outdir', amicaOutDir, ...
            'pcakeep', dataRank, 'num_models', 1, 'do_reject', 1, 'numrej', 15, ...
            'rejsig', 3, 'rejint', 1);
    end
    
    try
        modout = loadmodout15(amicaOutDir);
        EEG.etc.amica = modout;
        EEG.etc.amica.S = EEG.etc.amica.S(1:EEG.etc.amica.num_pcs, :);
        EEG.icaweights = EEG.etc.amica.W;
        EEG.icasphere  = EEG.etc.amica.S;
        EEG = eeg_checkset(EEG, 'ica');
        fprintf('  AMICA завантажена.\n');
    catch
        warning('  Помилка AMICA для %s. Пропускаю DIPFIT.', dataName);
        continue; 
    end

    % --- DIPFIT ---
    [~, coordinateTransformParameters] = coregister(EEG.chanlocs, templateChannelFilePath, 'warp', 'auto', 'manual', 'off');
    EEG = pop_dipfit_settings(EEG, 'hdmfile', hdmFilePath, 'coordformat', 'MNI', ...
            'mrifile', mriFilePath, 'chanfile', templateChannelFilePath, 'coord_transform', ...
            coordinateTransformParameters, 'chansel', 1:EEG.nbchan);
    EEG = pop_multifit(EEG, 1:EEG.nbchan, 'threshold', 100, 'dipplot', 'off', 'plotopt', {'normlen' 'on'});
    
   % --- ICLabel ---
    EEG = iclabel(EEG, 'default');
    
    % Ми НЕ обрізаємо матрицю класифікацій. Ми просто зберігаємо список хороших компонентів у окрему змінну всередині EEG, щоб ти їх бачив.
    
    [~, classIdx] = max(EEG.etc.ic_classification.ICLabel.classifications, [], 2);
    brainIdx = find(classIdx == 1); 
    rvList = [EEG.dipfit.model.rv];
    goodRvIdx = find(rvList < 0.15)'; 
    
    load(EEG.dipfit.hdmfile, 'vol');
    dipoleXyz = zeros(length(EEG.dipfit.model), 3);
    for icIdx = 1:length(EEG.dipfit.model)
        dipoleXyz(icIdx, :) = EEG.dipfit.model(icIdx).posxyz(1, :);
    end
    
    try
        depth = ft_sourcedepth(dipoleXyz, vol);
        insideBrainIdx = find(depth <= 1);
    catch
        insideBrainIdx = 1:length(dipoleXyz);
    end
    
    % Знаходимо наші ідеальні компоненти
    goodIcIdx = intersect(brainIdx, goodRvIdx);
    goodIcIdx = intersect(goodIcIdx, insideBrainIdx);
    
    % Записуємо список хороших компонентів у нотатки (щоб не ламати GUI)
    % ВИПРАВЛЕНО: додано (:)` щоб перетворити стовпчик на рядок
    EEG.notes = ['Автоматично відібрані хороші компоненти: ', num2str(goodIcIdx(:)')];
    fprintf('  Знайдено %d хороших компонентів.\n', length(goodIcIdx));
    
    %Очищення кешу іса
    EEG.icaact = [];

    % --- ЗБЕРЕЖЕННЯ ---
    EEG = pop_saveset(EEG, 'filename', [EEG.setname, '.set'], 'filepath', outputDirectory);
    fprintf('  Збережено: %s\n', [EEG.setname, '.set']);
end
disp('=== ВСЕ ГОТОВО ===');