INSERT INTO chat_user (id, allow_private_message, email, is_email_verified, last_online, password)
VALUES
    (1, 1, 'user1@example.com', 1, '2024-01-15 10:30:00.000000', 'hashed_password_1'),
    (2, 0, 'user2@example.com', 0, '2024-01-14 15:45:30.123456', 'hashed_password_2'),
    (3, 1, 'user3@example.com', 1, '2024-01-10 08:20:15.654321', 'hashed_password_3'),
    (4, 1, 'user4@example.com', 0, '2024-01-15 20:10:45.987654', 'hashed_password_4');

INSERT INTO chat_conversation (conversation_id, created_at, user1_id, user2_id)
VALUES
    (1, '2024-01-15 11:30:00.000000', 1, 2),
    (2, '2024-01-14 16:45:30.123456', 1, 3),
    (3, '2024-01-15 21:10:45.987654', 2, 4),
    (4, '2024-01-16 09:15:20.555555', 3, 4),
    (5, '2024-01-16 14:25:35.777777', 1, 4);
Query OK, 5 rows affected (0.01 sec)
Records: 5  Duplicates: 0  Warnings: 0