% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. НАЛАШТУВАННЯ ---
baseDirectory = 'X:\EEGMAG\ab3';
tableFile = fullfile(baseDirectory, 'PSD_Results_Grouped.csv'); 

% Один головний Excel-файл для всіх результатів
outputExcelFile = fullfile(baseDirectory, 'Statistics_Reactivity_AllBands.xlsx');

% Якщо старий файл існує, краще його видалити, щоб не було конфліктів вкладок
if exist(outputExcelFile, 'file')
    delete(outputExcelFile);
end

targetBands = {'Theta', 'Alpha', 'Beta', 'Gamma'}; 

% Зони інтересу (ROI)
ROIs = struct();
ROIs.Frontal = {'Fp1', 'Fp2', 'F3', 'F4', 'Fz', 'F7', 'F8'};
ROIs.Central = {'C3', 'C4', 'Cz'};
ROIs.Parietal = {'P3', 'P4', 'Pz', 'P7', 'P8'};
ROIs.Occipital = {'O1', 'O2'};
roiNames = fieldnames(ROIs);

% --- 2. ЧИТАННЯ ДАНИХ ---
fprintf('Читання таблиці PSD...\n');
T = readtable(tableFile);
subjects = unique(T.Subject);

% --- 3. ГОЛОВНИЙ ЦИКЛ ПО РИТМАХ ---
for b = 1:length(targetBands)
    targetBand = targetBands{b};
    
    fprintf('\n======================================================\n');
    fprintf('📊 Аналіз та експорт ритму: %s\n', upper(targetBand));
    fprintf('======================================================\n');

    SubjectList = {}; GroupList = {}; ReactMatrix = [];
    
    colNames = T.Properties.VariableNames;
    bandCols = colNames(endsWith(colNames, ['_', targetBand], 'IgnoreCase', true));

    if isempty(bandCols), continue; end

    cleanChans = cell(1, length(bandCols));
    for c = 1:length(bandCols)
        cleanChans{c} = strrep(bandCols{c}, sprintf('_%s', targetBand), '');
    end

    % --- УСЕРЕДНЕННЯ ПО РЕСПОНДЕНТАХ ---
    for s = 1:length(subjects)
        subj = subjects{s};
        idxSubj = strcmp(T.Subject, subj);
        groupName = char(T.Group{find(idxSubj, 1)}); 
        
        if strcmp(groupName, 'Unknown'), continue; end
        
        idxCross = idxSubj & strcmpi(T.Condition, 'Cross');
        idxSlide = idxSubj & strcmpi(T.Condition, 'Slide');
        
        if sum(idxCross) == 0 || sum(idxSlide) == 0, continue; end
        
        SubjectList{end+1, 1} = subj;
        GroupList{end+1, 1} = groupName;
        
        subjReact = zeros(1, length(bandCols) + length(roiNames));
        
        for c = 1:length(bandCols)
            col = bandCols{c};
            mCross = mean(T{idxCross, col}, 'omitnan');
            mSlide = mean(T{idxSlide, col}, 'omitnan');
            
            if mCross > 0 && mSlide > 0
                subjReact(c) = 10 * log10(mSlide / mCross);
            else
                subjReact(c) = NaN;
            end
        end
        
        for r = 1:length(roiNames)
            roiChans = ROIs.(roiNames{r});
            idxROI = ismember(cleanChans, roiChans);
            subjReact(length(bandCols) + r) = mean(subjReact(idxROI), 'omitnan');
        end
        
        ReactMatrix = [ReactMatrix; subjReact];
    end

    allVarNames = [cleanChans, roiNames'];

    % --- СТАТИСТИКА (Власна функція t-тесту) ---
    idxControl = strcmp(GroupList, 'Control');
    idxAnorexia = strcmp(GroupList, 'Anorexia');

    statResults = {};
    pValuesRaw = [];

    for v = 1:length(allVarNames)
        dataControl = ReactMatrix(idxControl, v);
        dataAnorexia = ReactMatrix(idxAnorexia, v);
        
        dataControl = dataControl(~isnan(dataControl));
        dataAnorexia = dataAnorexia(~isnan(dataAnorexia));
        
        if length(dataControl) < 2 || length(dataAnorexia) < 2
            continue; 
        end
        
        [t_val, df, p] = custom_ttest2(dataAnorexia, dataControl);
        pValuesRaw(end+1) = p;
        
        % Додаємо порожні місця для Бонферроні та Зірочок
        statResults(end+1, :) = {allVarNames{v}, mean(dataAnorexia), mean(dataControl), t_val, df, p, 0, ''}; 
    end
    
    % --- КОРЕКЦІЯ ТА ЗІРОЧКИ ЗНАЧУЩОСТІ ---
    numTests = length(pValuesRaw);
    pValuesAdj = min(pValuesRaw * numTests, 1.0);
    
    for i = 1:length(pValuesAdj)
        statResults{i, 7} = pValuesAdj(i);
        
        % Ставимо зірочки для наочності (за raw p-value)
        p_val = statResults{i, 6};
        if p_val < 0.001
            statResults{i, 8} = '***';
        elseif p_val < 0.01
            statResults{i, 8} = '**';
        elseif p_val < 0.05
            statResults{i, 8} = '*';
        elseif p_val < 0.1
            statResults{i, 8} = '+'; % Тенденція
        else
            statResults{i, 8} = 'ns'; % Незначуще (not significant)
        end
    end

    % Формування таблиці
    StatTable = cell2table(statResults, 'VariableNames', {'Region', 'Mean_Anorexia_dB', 'Mean_Control_dB', 't_value', 'df', 'p_raw', 'p_Bonferroni', 'Significance'});
    StatTable = sortrows(StatTable, 'p_raw');
    
    % --- ЕКСПОРТ В EXCEL ---
    % Записуємо кожен ритм в окрему вкладку (Sheet)
    writetable(StatTable, outputExcelFile, 'Sheet', upper(targetBand));
    
    % Вивід у консоль для швидкого перегляду
    sigResults = StatTable(StatTable.p_raw < 0.05, :);
    if height(sigResults) > 0
        disp(sigResults(:, {'Region', 'Mean_Anorexia_dB', 'Mean_Control_dB', 'p_raw', 'Significance'}));
    else
        disp('Значущих відмінностей не знайдено.');
    end
end

fprintf('\n=== ВСІ ДАНІ ЗБЕРЕЖЕНО В EXCEL: %s ===\n', outputExcelFile);

% =========================================================================
% ВЛАСНА ФУНКЦІЯ ДЛЯ СТАТИСТИКИ 
% =========================================================================
function [t_val, df, p_val] = custom_ttest2(x, y)
    n1 = length(x); n2 = length(y);
    m1 = mean(x); m2 = mean(y);
    v1 = var(x); v2 = var(y);
    
    se = sqrt(v1/n1 + v2/n2);
    if se == 0
        t_val = 0; df = n1 + n2 - 2; p_val = 1;
        return;
    end
    t_val = (m1 - m2) / se;
    
    df = (v1/n1 + v2/n2)^2 / ((v1/n1)^2/(n1-1) + (v2/n2)^2/(n2-1));
    x_beta = df / (df + t_val^2);
    p_val = betainc(x_beta, df/2, 0.5);
end