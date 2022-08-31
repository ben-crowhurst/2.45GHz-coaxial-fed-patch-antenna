function render
    figures = allchild(0);

    screen_size = get(0, 'screensize');

    position = get(gcf, 'Position');
    current = position;

    row_index = 1;
    column_index = 1;

    for index = 1:numel(figures)
        % Screen width exceeded or max columns.
        if sum(current([1, 3])) > screen_size(3) || column_index > inf
            column_index = 1;
            row_index = row_index + 1;
            current(1) = position(1);
            current(2) = current(2) - current(4);
        end

        % Screen height exceeded or max rows.
        if current(2) < 0 || row_index > inf
            row_index = 1;
            current(2) = position(2);
        end

        set(figures(index), 'Position', current);

        column_index = column_index + 1;
        current = current + [current(3), 0, 0, 0];
    end

    % Flip overlap.
    for index = numel(figures):-1:1
        figure(figures(index));
    end

end
