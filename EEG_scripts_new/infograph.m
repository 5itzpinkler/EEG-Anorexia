% Close all figures, clear variables, and clear command window
close all; clear variables; clc;

% --- 1. НАЛАШТУВАННЯ ---
baseDirectory = 'X:\EEGMAG\ab3';
tableFile = fullfile(baseDirectory, 'PSD_Results_Grouped.csv'); 

% Канали, які ми хочемо показати на графіку
channelsToPlot = {'F7_Alpha', 'P7_Alpha'};
titles = {'Лобна асиметрія (F7): Уникнення', 'Візуальна увага (P7): Активація'};

% Кольори для груп (RGB)
colorControl = [0.298, 0.447, 0.690];  % Приємний синій
colorAnorexia = [0.768, 0.305, 0.321]; % М'який червоний

% --- 2. ПІДГОТОВКА ДАНИХ ---
fprintf('Читання таблиці для інфографіки...\n');
T = readtable(tableFile);
subjects = unique(T.Subject);

DataControl = cell(1, 2);
DataAnorexia = cell(1, 2);

for s = 1:length(subjects)
    subj = subjects{s};
    idxSubj = strcmp(T.Subject, subj);
    groupName = char(T.Group{find(idxSubj, 1)}); 
    
    if strcmp(groupName, 'Unknown'), continue; end
    
    idxCross = idxSubj & strcmpi(T.Condition, 'Cross');
    idxSlide = idxSubj & strcmpi(T.Condition, 'Slide');
    
    if sum(idxCross) == 0 || sum(idxSlide) == 0, continue; end
    
    for c = 1:2
        chan = channelsToPlot{c};
        mCross = mean(T{idxCross, chan}, 'omitnan');
        mSlide = mean(T{idxSlide, chan}, 'omitnan');
        
        if mCross > 0 && mSlide > 0
            dB_val = 10 * log10(mSlide / mCross);
            
            if strcmp(groupName, 'Control')
                DataControl{c}(end+1) = dB_val;
            else
                DataAnorexia{c}(end+1) = dB_val;
            end
        end
    end
end

% --- 3. МАЛЮВАННЯ ГРАФІКА ---
figure('Name', 'Alpha Reactivity Infographic', 'Position', [100, 100, 900, 600], 'Color', 'w');

for c = 1:2
    subplot(1, 2, c);
    hold on;
    
    % Дані для графіка
    y_ctrl = DataControl{c}';
    y_anor = DataAnorexia{c}';
    
    % Середні та стандартні похибки (SEM)
    mean_ctrl = mean(y_ctrl); sem_ctrl = std(y_ctrl) / sqrt(length(y_ctrl));
    mean_anor = mean(y_anor); sem_anor = std(y_anor) / sqrt(length(y_anor));
    
    % Малюємо стовпчики
    b1 = bar(1, mean_ctrl, 0.4, 'FaceColor', colorControl, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    b2 = bar(2, mean_anor, 0.4, 'FaceColor', colorAnorexia, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    
    % Малюємо лінії похибки
    errorbar(1, mean_ctrl, sem_ctrl, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 10);
    errorbar(2, mean_anor, sem_anor, 'k', 'LineStyle', 'none', 'LineWidth', 1.5, 'CapSize', 10);
    
    % Додаємо індивідуальні точки (Scatter з "тремтінням" - jitter)
    jitter = (rand(size(y_ctrl)) - 0.5) * 0.15;
    scatter(ones(size(y_ctrl)) + jitter, y_ctrl, 30, 'k', 'filled', 'MarkerFaceAlpha', 0.4);
    
    jitter = (rand(size(y_anor)) - 0.5) * 0.15;
    scatter(ones(size(y_anor))*2 + jitter, y_anor, 30, 'k', 'filled', 'MarkerFaceAlpha', 0.4);
    
    % Оформлення
    yline(0, 'k--', 'LineWidth', 1.2); % Нульова лінія
    
    % Значущість (через нашу власну функцію)
    [~, ~, p] = custom_ttest2(y_anor, y_ctrl);
    
    if p < 0.05
        max_y = max([y_ctrl; y_anor]) + 0.5;
        plot([1, 2], [max_y, max_y], '-k', 'LineWidth', 1.5);
        if p < 0.01, star = '**'; else, star = '*'; end
        text(1.5, max_y + 0.1, star, 'FontSize', 16, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end
    
    set(gca, 'XTick', [1, 2], 'XTickLabel', {'Контроль', 'Анорексія'}, 'FontSize', 12, 'LineWidth', 1.2);
    ylabel('Реактивність Альфа-ритму (dB)', 'FontSize', 12, 'FontWeight', 'bold');
    title(titles{c}, 'FontSize', 14, 'FontWeight', 'bold');
    
    % Межі осі Y
    ylim([min([y_ctrl; y_anor])-0.5, max([y_ctrl; y_anor])+1]);
    box off;
end

% Додаємо легенду на перший графік
subplot(1, 2, 1);
legend([b1, b2], {'Контроль', 'Анорексія'}, 'Location', 'best', 'FontSize', 11, 'Box', 'off');

disp('=== ІНФОГРАФІКА ЗГЕНЕРОВАНА ===');

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