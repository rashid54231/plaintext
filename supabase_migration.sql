-- ============================================
-- TaskFlow App - Supabase Migration
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================

-- 1. Create Users Table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('manager', 'student')),
  phone TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create Tasks Table
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  assigned_date TIMESTAMPTZ DEFAULT now(),
  due_date TIMESTAMPTZ NOT NULL,
  is_completed BOOLEAN DEFAULT false,
  completed_date TIMESTAMPTZ,
  assigned_to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  submission_path TEXT,
  review_comment TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'inProgress', 'completed', 'overdue')),
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  category TEXT
);

-- 3. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON tasks(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_by ON tasks(assigned_by_user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- 4. Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES FOR USERS TABLE
-- ============================================

-- Everyone can read their own profile
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

-- Manager can view all students
CREATE POLICY "Manager can view all students"
  ON users FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'manager'
    )
  );

-- Anyone can signup (insert)
CREATE POLICY "Allow signup"
  ON users FOR INSERT
  WITH CHECK (true);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- ============================================
-- RLS POLICIES FOR TASKS TABLE
-- ============================================

-- Manager can view all tasks
CREATE POLICY "Manager can view all tasks"
  ON tasks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'manager'
    )
  );

-- Student can view tasks assigned to them
CREATE POLICY "Student can view own tasks"
  ON tasks FOR SELECT
  USING (assigned_to_user_id = auth.uid());

-- Manager can create tasks
CREATE POLICY "Manager can create tasks"
  ON tasks FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'manager'
    )
  );

-- Manager can update any task
CREATE POLICY "Manager can update tasks"
  ON tasks FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'manager'
    )
  );

-- Student can update tasks assigned to them (for completion)
CREATE POLICY "Student can update own tasks"
  ON tasks FOR UPDATE
  USING (assigned_to_user_id = auth.uid());

-- Manager can delete tasks
CREATE POLICY "Manager can delete tasks"
  ON tasks FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'manager'
    )
  );

-- ============================================
-- FUNCTION: Auto-check if manager already exists
-- ============================================
CREATE OR REPLACE FUNCTION check_manager_exists()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'manager' THEN
    IF EXISTS (SELECT 1 FROM users WHERE role = 'manager') THEN
      RAISE EXCEPTION 'Only one manager can be registered';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce single manager
CREATE TRIGGER enforce_single_manager
  BEFORE INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION check_manager_exists();

-- ============================================
-- FUNCTION: Auto-update task status when overdue
-- ============================================
CREATE OR REPLACE FUNCTION update_overdue_tasks()
RETURNS void AS $$
BEGIN
  UPDATE tasks
  SET status = 'overdue'
  WHERE is_completed = false
    AND due_date < now()
    AND status != 'overdue';
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get task statistics for a user
-- ============================================
CREATE OR REPLACE FUNCTION get_user_task_stats(p_user_id UUID)
RETURNS TABLE (
  total_tasks BIGINT,
  completed_tasks BIGINT,
  pending_tasks BIGINT,
  overdue_tasks BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) as total_tasks,
    COUNT(*) FILTER (WHERE is_completed = true) as completed_tasks,
    COUNT(*) FILTER (WHERE is_completed = false AND due_date >= now()) as pending_tasks,
    COUNT(*) FILTER (WHERE is_completed = false AND due_date < now()) as overdue_tasks
  FROM tasks
  WHERE assigned_to_user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;
