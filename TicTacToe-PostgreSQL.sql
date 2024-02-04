CREATE OR REPLACE FUNCTION NewGame()
RETURNS int AS $$
DECLARE 
	game_id int;
BEGIN
	CREATE TABLE IF NOT EXISTS TicTacToe (
    id SERIAL PRIMARY KEY,
    player_symbol CHAR(1),
    board CHAR(3)[],
    game_over BOOLEAN DEFAULT FALSE);
	
    INSERT INTO TicTacToe (player_symbol, board)
    VALUES ('X', ARRAY[['_', '_', '_'], ['_', '_', '_'], ['_', '_', '_']])
	RETURNING id into game_id;
	RETURN game_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SeeBoard(game_id INT)
RETURNS TABLE (col1 CHAR, col2 CHAR, col3 CHAR) AS $$
BEGIN
	RETURN QUERY
			SELECT
			unnest(board[1:3][1:1]) AS col1,
			unnest(board[1:3][2:2]) AS col2,
			unnest(board[1:3][3:3]) AS col3
			FROM TicTacToe
			WHERE id = game_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION NextMove(game_id INT, X INT, Y INT, Val CHAR DEFAULT NULL)
RETURNS TABLE (game_result TEXT, col1 CHAR, col2 CHAR, col3 CHAR) AS $$
DECLARE
    current_board CHAR(3)[];
    current_player CHAR(1);
	game_is_over BOOLEAN;
	winner CHAR(1);
	total_moves INT;
BEGIN
    SELECT board, player_symbol, game_over
    INTO current_board, current_player, game_is_over
    FROM TicTacToe
    WHERE id = game_id;
	
	IF current_player IS NULL OR game_is_over THEN
        RAISE EXCEPTION 'The game is already over.';
    END IF;
    IF X < 1 OR X > 3 OR Y < 1 OR Y > 3 THEN
        RAISE EXCEPTION 'Invalid move. Coordinates out of bounds.';
    END IF;
	IF current_board[X][Y] <> '_' THEN
        RAISE EXCEPTION 'Invalid move. Cell already occupied.';
    END IF;
	IF Val <> current_player THEN
        RAISE EXCEPTION 'Invalid sign.';
    END IF;
	
	current_board[X][Y] := current_player;
	
	FOR i IN 1..3 LOOP
        -- Check rows and columns
        IF current_board[i][1] = current_board[i][2] AND current_board[i][1] = current_board[i][3] AND current_board[i][1] <> '_' THEN
            winner := current_board[i][1];
        ELSIF current_board[1][i] = current_board[2][i] AND current_board[1][i] = current_board[3][i] AND current_board[1][i] <> '_' THEN
            winner := current_board[1][i];
        END IF;
    END LOOP;

    -- Check diagonals
    IF current_board[1][1] = current_board[2][2] AND current_board[1][1] = current_board[3][3] AND current_board[1][1] <> '_' THEN
        winner := current_board[1][1];
    ELSIF current_board[1][3] = current_board[2][2] AND current_board[1][3] = current_board[3][1] AND current_board[1][3] <> '_' THEN
        winner := current_board[1][3];
    END IF;
	
	total_moves := (SELECT COUNT(*) FROM unnest(current_board) t(cell) WHERE cell <> '_');
	
	IF total_moves = 9 THEN
        UPDATE TicTacToe
        SET board = current_board,
            player_symbol = NULL,
            game_over = TRUE
        WHERE id = game_id;
        game_result := 'It''s a draw.';
        RETURN QUERY
            SELECT game_result,
				unnest(board[1:3][1:1]) AS col1,
                unnest(board[1:3][2:2]) AS col2,
                unnest(board[1:3][3:3]) AS col3
            FROM TicTacToe
            WHERE id = game_id;
        RETURN;
    END IF;
	
	IF winner IS NOT NULL THEN
        UPDATE TicTacToe
        SET board = current_board,
            player_symbol = NULL,
            game_over = TRUE
        WHERE id = game_id;
		game_result := 'Game is over! The winner: ' || winner;
		RETURN QUERY
			SELECT game_result,
			unnest(board[1:3][1:1]) AS col1,
			unnest(board[1:3][2:2]) AS col2,
			unnest(board[1:3][3:3]) AS col3
			FROM TicTacToe
			WHERE id = game_id;
    ELSE
        UPDATE TicTacToe
        SET board = current_board,
            player_symbol = CASE WHEN current_player = 'X' THEN 'O' ELSE 'X' END
        WHERE id = game_id;
		game_result := 'Your next move?';
		RETURN QUERY
			SELECT game_result,
			unnest(board[1:3][1:1]) AS col1,
			unnest(board[1:3][2:2]) AS col2,
			unnest(board[1:3][3:3]) AS col3
			FROM TicTacToe
			WHERE id = game_id;
    END IF;

END;
$$ LANGUAGE plpgsql;