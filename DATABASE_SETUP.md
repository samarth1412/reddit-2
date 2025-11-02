# Database Setup Instructions

## Overview

The project now uses **PostgreSQL** for persistent data storage instead of in-memory dictionaries. This provides a more realistic, production-like implementation.

## Prerequisites

1. **Install PostgreSQL:**
   - Windows: Download from https://www.postgresql.org/download/windows/
   - macOS: `brew install postgresql`
   - Linux: `sudo apt-get install postgresql` (Ubuntu/Debian)

2. **Start PostgreSQL service:**
   - Windows: PostgreSQL runs as a service (usually auto-starts)
   - macOS/Linux: `brew services start postgresql` or `sudo systemctl start postgresql`

## Database Setup

1. **Create database:**
   ```bash
   createdb reddit_clone
   ```

2. **Set environment variable (or update connection string):**
   ```bash
   export DATABASE_URL="postgresql://localhost/reddit_clone"
   ```

   Or for Windows PowerShell:
   ```powershell
   $env:DATABASE_URL="postgresql://localhost/reddit_clone"
   ```

3. **Default connection (if no env var):**
   - Host: localhost
   - Port: 5432 (default)
   - Database: reddit_clone
   - User: Your PostgreSQL username
   - Password: Your PostgreSQL password

## Running the Project

The database schema will be automatically created on first run. Make sure PostgreSQL is running before starting the simulator.

```bash
gleam run
```

## Database Schema

The following tables are created automatically:

- `users` - User accounts with karma
- `user_subreddits` - Many-to-many relationship (users <-> subreddits)
- `subreddits` - Subreddit information
- `subreddit_posts` - Many-to-many relationship (subreddits <-> posts)
- `posts` - Post content and metadata
- `post_comments` - Many-to-many relationship (posts <-> comments)
- `comments` - Comment content (hierarchical)
- `comment_replies` - Comment reply relationships
- `messages` - Direct messages
- `message_replies` - Message reply relationships

## Benefits of Database Approach

✅ **Persistent Storage** - Data survives process restarts
✅ **Real-world Implementation** - Production-ready architecture
✅ **Scalability** - Can handle larger datasets
✅ **Data Integrity** - Foreign keys and constraints
✅ **Query Flexibility** - SQL queries for complex operations

## Migration Notes

- The engine has been updated to use PostgreSQL instead of dictionaries
- All data operations now persist to the database
- Connection pooling will be handled automatically by pog

## Troubleshooting

**Connection Error:**
- Ensure PostgreSQL is running: `psql -l` should list databases
- Check DATABASE_URL environment variable
- Verify database exists: `createdb reddit_clone`

**Permission Errors:**
- Ensure your PostgreSQL user has CREATE TABLE permissions
- Check pg_hba.conf for authentication settings

