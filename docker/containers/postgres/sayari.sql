
-- Soft deletes, allows for recovering an unintentionally deleted account, retains user record for auditing if they opt to delete their account.
CREATE TABLE users
(
  id SERIAL PRIMARY KEY,
  username varchar(40) NOT NULL UNIQUE,                  -- username should be guaranteed unique
  first_name varchar(50) NOT NULL,
  last_name varchar(50) NOT NULL,
  password varchar(60) NOT NULL,
  email varchar(50) NOT NULL UNIQUE,                     -- email should be guaranteed unique
  created_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  website_url varchar(255) NULL,
  github_username varchar(40) NULL,
  avatar_url varchar(255) NULL,
  updated_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deletion_date timestamp NULL
);

-- Single column indexes on created_date / updated_date for future reporting (users updated within X time, new users since Y date)
CREATE INDEX idx_users_created_date ON users (created_date);
CREATE INDEX idx_users_updated_date ON users (updated_date);

-- Composite indexes because we're gonna want to search for "not deleted" users matching a specified email or username
CREATE INDEX idx_users_username_deletion_date ON users (username, deletion_date);
CREATE INDEX idx_users_email_deletion_date ON users (email, deletion_date);

-- Composite index because we may want to search for users that joined after X date who are not "deleted"
CREATE INDEX idx_users_created_date_deletion_date ON users (created_date, deletion_date);

-- Aggregate stats, recalculated daily (not real time). Immutable so we can track historical data. Prune after X retention period.
CREATE TABLE user_stats
(
  user_id integer NOT NULL REFERENCES users (id),
  reputation integer NOT NULL DEFAULT 0,                                                                                -- signed, negative reputation is theoritically possible
  total_reach integer NOT NULL DEFAULT 0 CONSTRAINT con_user_stats_total_reach_positive CHECK (total_reach >= 0),       -- unsigned, can have zero reach but not negative
  num_answers integer NOT NULL DEFAULT 0 CONSTRAINT con_user_stats_num_answers_positive CHECK (num_answers >= 0),       -- unsigned, can't have less than zero answers posted
  num_questions integer NOT NULL DEFAULT 0 CONSTRAINT con_user_stats_num_questions_positive CHECK (num_questions >= 0), -- unsigned, can't have less than zero questions posted
  insertion_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Composite index on user id & insertion date, we'll want to query latest status for a given user
CREATE INDEX idx_user_stats_user_id_insertion_date ON user_stats (user_id, insertion_date);

-- Indexes on reputation, total_reach, num_answers, num questions incase we want future reporting (find users with reputation > X, reach > Y, etc). 
-- Likely we'd query these columns individually, so a composite index wouldn't add value here.
CREATE INDEX idx_user_stats_reputation ON user_stats (reputation);
CREATE INDEX idx_user_stats_total_reach ON user_stats (total_reach);
CREATE INDEX idx_user_stats_num_questions ON user_stats (num_questions);
CREATE INDEX idx_user_stats_num_answers ON user_stats (num_answers);

-- Soft deletes, we want an audit for "deleted" questions (e.g. inappropriate content w/ dirty delete)
CREATE TABLE questions
(
  id SERIAL PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users (id),
  posted_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  score integer NOT NULL DEFAULT 0,                        -- signed, score can theoritically be negative
  body text NOT NULL,
  deletion_date timestamp NULL
);

-- Indexes on user_id, posted_date, score, deletion_date. We may want to query X recent questions for a user, or X top scoring questions, etc that are not "deleted".
-- Queries could be any combination of user, score, posted date, etc so we're using single column indexes here.
CREATE INDEX fk_questions_user_id ON questions (user_id);
CREATE INDEX idx_questions_posted_date ON questions (posted_date);
CREATE INDEX idx_questions_score ON questions (score);
CREATE INDEX idx_questions_deletion_date ON questions (deletion_date);

-- Soft deletes, we want an audit for "deleted" answers (e.g. inappropriate content w/ dirty delete)
CREATE TABLE answers
(
  id SERIAL PRIMARY KEY,
  question_id integer NOT NULL REFERENCES questions (id),
  user_id integer NOT NULL REFERENCES users (id),
  body text NOT NULL,
  posted_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  accepted_date timestamp NULL,
  deletion_date timestamp NULL
);

-- Indexes on question_id, user_id, posted_date, accepted_date, deletion_date. 
-- Queries could be any combination of question/user, question/date, user/date, etc that are not "deleted", hence we're using single column indexes.
CREATE INDEX fk_answers_question_id ON answers (question_id);
CREATE INDEX fk_answers_user_id ON answers (user_id);
CREATE INDEX idx_answers_posted_date ON answers (posted_date);
CREATE INDEX idx_answers_accepted_date ON answers (accepted_date);
CREATE INDEX idx_answers_deletion_date ON answers (deletion_date);

-- Simple lookup table to identify what type of record a comment is associated with
CREATE TABLE parent_types
(
  id SERIAL PRIMARY KEY,
  type varchar(25) NOT NULL UNIQUE
);

-- Available parent types are "question", "answer", "comment" (a comment can be in response to another comment - ie. threading)
INSERT INTO parent_types (type) VALUES ('question'), ('answer'), ('comment');

-- Soft deletes, we want an audit for "deleted" comments (e.g. inappropriate content w/ dirty delete)
CREATE TABLE comments
(
  id SERIAL PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users (id),
  parent_id integer NOT NULL CONSTRAINT con_comments_parent_id_positive CHECK (parent_id > 0), -- Polymorphic (could join to comments, questions, or answers), so we can't use "REFERENCES"
  parent_type_id integer NOT NULL REFERENCES parent_types (id),
  body text NOT NULL,
  posted_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, 
  deletion_date timestamp NULL
);

-- Single column indexes on user_id, posted_date, deletion_date (we may want to query by either user or post date for not "deleted" comments).
-- Composite index on parent_id, parent_type_id since "parent" is polymorphic (it could be another comment, a question, or an answer), so we always need to check the type.
CREATE INDEX fk_comments_user_id ON comments (user_id);
CREATE INDEX idx_comments_posted_date ON comments (posted_date);
CREATE INDEX idx_comments_deletion_date ON comments (deletion_date);
CREATE INDEX idx_comments_parent_id_parent_type_id ON comments (parent_id, parent_type_id);

-- Individual votes (up/down) for questions/answers
-- Value +1 = upvote, -1 = downvote (we can simply sum these for aggregate stats)
CREATE TABLE votes
(
  id SERIAL PRIMARY KEY,
  value smallint NOT NULL,
  parent_id integer NOT NULL CONSTRAINT con_votes_parent_id_positive CHECK (parent_id > 0), -- Polymorphic (could join to comments, questions, or answers), so we can't use "REFERENCES"
  parent_type_id integer NOT NULL REFERENCES parent_types (id)
);

-- Single column index on value (reports may want to track up vs down votes).
-- Composite index on parent_id, parent_type_id since "parent" is polymorphic (it could be a comment, a question, or an answer), so we always need to check the type.
CREATE INDEX idx_votes_value ON votes (value);
CREATE INDEX idx_votes_parent_id_parent_type_id ON votes (parent_id, parent_type_id);

-- Tags (e.g. "Typescript", "Javascript", "Programming", etc) that be associated with questions
CREATE TABLE tags
(
  id SERIAL PRIMARY KEY,
  tag varchar(50) NOT NULL UNIQUE,
  description text NOT NULL,
  created_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index created_date on tags (tag itself already has a unique index)
CREATE INDEX idx_tags_created_date ON tags (created_date);


-- Mapping table for questions<->tags. Many-to-many (question can have multiple tags, each tag can be associated with multiple questions).
CREATE TABLE questions_tags
(
  question_id integer NOT NULL REFERENCES questions (id),
  tag_id integer NOT NULL REFERENCES tags (id),
  added_date timestamp NOT NULL,
  PRIMARY KEY (question_id, tag_id)                      -- Composite primary key, rather than a numeric primary and a unique key here
);

-- Individual indexes on question_id / tag_id allows us to query all tags for a question, or all questions for a tag.
-- Index on added_date allows for sorting/reporting tags by date (e.g. list of tags added to question X within Y days)
CREATE INDEX idx_questions_tags_question_id ON questions_tags (question_id);
CREATE INDEX idx_questions_tags_tag_id ON questions_tags (tag_id);
CREATE INDEX idx_questions_tags_added_date ON questions_tags (added_date);
