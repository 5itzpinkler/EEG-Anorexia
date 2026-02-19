% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. НАЛАШТУВАННЯ ШЛЯХІВ ---
baseDirectory = 'X:\EEGMAG\ab3';
eeglabDirectory = 'X:\eeglab2025.1.0\plugins';

% Шлях до файлу локацій каналів (Enobio 19)
chanloc = fullfile(eeglabDirectory, 'NE_EEGLAB_NIC_Plugin_v1.9', 'Locations', 'Enobio19Chan.locs');

outputDirectory = fullfile(baseDirectory, 'Data_Sinhronizovane');
universalEventFile = fullfile(baseDirectory, 'universal_schema.txt');

% Запускаємо EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% --- ПЕРЕВІРКИ ПЕРЕД ЗАПУСКОМ ---
if ~exist(universalEventFile, 'file')
    error('Файл маркерів %s не знайдено!', universalEventFile);
end
if ~exist(chanloc, 'file')
    error('Файл локацій каналів %s не знайдено! Перевір шлях до плагіна.', chanloc);
end

respondentDirectories = dir(fullfile(baseDirectory, 'Data'));

for i = 3:length(respondentDirectories)      
    xdfFiles = dir(fullfile(baseDirectory, 'Data', respondentDirectories(i).name, '*.xdf'));
    
    for j = 1:length(xdfFiles)
        loadName = xdfFiles(j).name;
        dataName = loadName(1:end-4);
        
        % Перевірка тегів
        validTags = ["New1", "New2", "New3", "New4", "Old1", "Old2", "tive"];
        isValid = false;
        for tag = validTags
            if contains(dataName, tag), isValid = true; break; end
        end
        if ~isValid, continue; end
        
        fprintf('Обробка: %s\n', dataName);
        
        % --- 2. ЗАВАНТАЖЕННЯ ---
        xdfFilePath = fullfile(xdfFiles(j).folder, xdfFiles(j).name);
        EEG = pop_loadxdf(xdfFilePath, 'streamtype', 'EEG', 'exclude_markerstreams', {});
        EEG.setname = dataName;
        
        % --- 3. СИНХРОНІЗАЦІЯ (R released) ---
        idx = find(strcmp({EEG.event.type}, 'R released'), 1);
        if ~isempty(idx)
            start_latency = EEG.event(idx).latency;
            EEG = pop_select(EEG, 'time', [start_latency/EEG.srate EEG.xmax]);
        else
            warning('R released не знайдено в %s. Таймінг може бути збитий.', dataName);
        end
        
        % --- 4. ІМПОРТ МАРКЕРІВ (Universal Schema) ---
        EEG.event = []; % Чистимо старі події
        EEG = pop_importevent(EEG, 'event', universalEventFile, ...
            'fields', {'type', 'latency', 'duration'}, ...
            'skipline', 1, 'timeunit', 1);
        
        % === 5. ОБРІЗАННЯ ЗАЙВИХ КАНАЛІВ ===
        % Якщо Enobio записав технічні канали (наприклад, 20 замість 19),
        % видаляємо все, крім перших 19 електродів EEG.
        if EEG.nbchan > 19
            fprintf('  Знайдено %d каналів. Обрізаємо до 19 (EEG).\n', EEG.nbchan);
            EEG = pop_select(EEG, 'channel', 1:19);
        end
        
        % === 6. ЛОКАЦІЇ КАНАЛІВ (ФАЙЛ КЕРІВНИЦТВА) ===
        fprintf('  Завантаження локацій з оригінального файлу: %s\n', chanloc);
        
        try
            % 1. Читаємо файл локацій напряму в тимчасову змінну (обходимо pop_chanedit)
            imported_locs = readlocs(chanloc);
            
            % 2. Якщо файл керівництва має 20 рядків (включно з EXT), 
            % відрізаємо останній, щоб їх було рівно 19, як у наших обрізаних ЕЕГ даних
            if length(imported_locs) > 19
                imported_locs = imported_locs(1:19);
            end
            
            % 3. Насильно перезаписуємо структуру координат у нашому файлі
            EEG.chanlocs = imported_locs;
            
            % 4. Оновлюємо налаштування (перевірка цілісності)
            EEG = eeg_checkset(EEG);
            
            fprintf('  [+] Локації каналів Enobio19 успішно прив''язані.\n');
            
        catch ME
            warning('  [-] Помилка читання файлу: %s', ME.message);
            disp('  Переконайся, що у файлі немає розірваних рядків (як ми обговорювали раніше).');
        end
        % --- 6. ФІЛЬТРАЦІЯ ---
        EEG = pop_eegfiltnew(EEG, 'locutoff', 1, 'hicutoff', 45);
        
        % --- 7. ЗБЕРЕЖЕННЯ ---
        if ~exist(outputDirectory, 'dir'), mkdir(outputDirectory); end
        EEG = pop_saveset(EEG, 'filename', [EEG.setname, '.set'], 'filepath', outputDirectory);
    end
end
disp('Обробка завершена: Маркери + Локації каналів успішно додані.');