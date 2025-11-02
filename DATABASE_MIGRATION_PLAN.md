# Database Migration Plan - Future Implementation

## Overview

This document outlines the plan to migrate the Reddit Clone from in-memory dictionaries to PostgreSQL database for a more realistic, production-ready implementation.

**Status**: Initial planning phase - not yet implemented
**Priority**: Future enhancement (Part II or advanced implementation)
**Current Implementation**: In-memory dictionaries (works perfectly for Part I requirements)

---

## Migration Goals

### Objectives
1. Replace in-memory `dict.Dict` storage with PostgreSQL database
2. Add persistent data storage (survives process restarts)
3. Implement production-ready architecture
4. Maintain all existing functionality
5. Improve scalability for larger datasets

### Benefits
- ✅ **Persistent Storage**: Data survives application restarts
- ✅ **Production-Ready**: Real-world database architecture
- ✅ **Scalability**: Handle larger datasets efficiently
- ✅ **Data Integrity**: Foreign keys, constraints, transactions
- ✅ **Query Flexibility**: Complex SQL queries possible
- ✅ **Backup/Restore**: Standard database tools available

---

## Prerequisites & Requirements

### 1. Software Installation

#### PostgreSQL
- **Windows**: Download installer from https://www.postgresql.org/download/windows/
- **macOS**: `brew install postgresql && brew services start postgresql`
- **Linux**: `sudo apt-get install postgresql postgresql-contrib`

#### rebar3 (Erlang Build Tool)
- Required by `pog` library
- **Installation Options**:
  - Via Elixir: `mix escript.install hex rebar3`
  - Direct download: https://www.rebar3.org/
  - Add to PATH after installation

#### Verify Installation
```bash
# Check PostgreSQL
psql --version

# Check rebar3
rebar3 --version

# Check database is running
psql -l
```

### 2. Database Setup

```bash
# Create database
createdb reddit_clone

# Or using psql
psql -c "CREATE DATABASE reddit_clone;"

# Set environment variable
export DATABASE_URL="postgresql://username:password@localhost:5432/reddit_clone"
```

---

## Architecture Changes

### Current Architecture (Dict-Based)
```
EngineState {
  users: dict.Dict(String, User),
  subreddits: dict.Dict(String, Subreddit),
  posts: dict.Dict(String, Post),
  comments: dict.Dict(String, Comment),
  messages: dict.Dict(String, DirectMessage),
  ...
}
```

### New Architecture (Database-Based)
```
Database {
  connection: pog.Connection
}

EngineState {
  db: Database,
  // No in-memory storage
  // All data in PostgreSQL
}
```

---

## Database Schema Design

### Tables

1. **users**
   - `id` (TEXT PRIMARY KEY)
   - `username` (TEXT UNIQUE NOT NULL)
   - `karma` (INTEGER DEFAULT 0)

2. **subreddits**
   - `id` (TEXT PRIMARY KEY)
   - `name` (TEXT NOT NULL)
   - `creator_id` (TEXT FOREIGN KEY → users.id)

3. **user_subreddits** (junction table)
   - `user_id` (TEXT FOREIGN KEY → users.id)
   - `subreddit_id` (TEXT FOREIGN KEY → subreddits.id)
   - PRIMARY KEY (user_id, subreddit_id)

4. **posts**
   - `id` (TEXT PRIMARY KEY)
   - `subreddit_id` (TEXT FOREIGN KEY → subreddits.id)
   - `author_id` (TEXT FOREIGN KEY → users.id)
   - `title` (TEXT NOT NULL)
   - `content` (TEXT NOT NULL)
   - `upvotes` (INTEGER DEFAULT 0)
   - `downvotes` (INTEGER DEFAULT 0)
   - `created_at` (INTEGER/BIGINT)
   - `is_repost` (BOOLEAN DEFAULT FALSE)
   - `original_post_id` (TEXT FOREIGN KEY → posts.id, nullable)

5. **subreddit_posts** (junction table)
   - `subreddit_id` (TEXT FOREIGN KEY → subreddits.id)
   - `post_id` (TEXT FOREIGN KEY → posts.id)
   - PRIMARY KEY (subreddit_id, post_id)

6. **comments**
   - `id` (TEXT PRIMARY KEY)
   - `post_id` (TEXT FOREIGN KEY → posts.id)
   - `parent_comment_id` (TEXT FOREIGN KEY → comments.id, nullable)
   - `author_id` (TEXT FOREIGN KEY → users.id)
   - `content` (TEXT NOT NULL)
   - `upvotes` (INTEGER DEFAULT 0)
   - `downvotes` (INTEGER DEFAULT 0)
   - `created_at` (INTEGER/BIGINT)

7. **comment_replies** (junction table)
   - `parent_comment_id` (TEXT FOREIGN KEY → comments.id)
   - `reply_comment_id` (TEXT FOREIGN KEY → comments.id)
   - PRIMARY KEY (parent_comment_id, reply_comment_id)

8. **messages**
   - `id` (TEXT PRIMARY KEY)
   - `from_user_id` (TEXT FOREIGN KEY → users.id)
   - `to_user_id` (TEXT FOREIGN KEY → users.id)
   - `content` (TEXT NOT NULL)
   - `parent_message_id` (TEXT FOREIGN KEY → messages.id, nullable)
   - `created_at` (INTEGER/BIGINT)

9. **message_replies** (junction table)
   - `parent_message_id` (TEXT FOREIGN KEY → messages.id)
   - `reply_message_id` (TEXT FOREIGN KEY → messages.id)
   - PRIMARY KEY (parent_message_id, reply_message_id)

### Indexes (Performance Optimization)
- Index on `users.username` (already unique)
- Index on `posts.subreddit_id`
- Index on `posts.author_id`
- Index on `comments.post_id`
- Index on `comments.parent_comment_id`
- Index on `messages.to_user_id`
- Index on `user_subreddits.user_id`
- Index on `user_subreddits.subreddit_id`

---

## Implementation Steps

### Phase 1: Database Module (Database Layer)
**File**: `src/reddit_engine/database.gleam`

**Tasks**:
1. ✅ Create Database type wrapper
2. ✅ Implement `init()` - Database connection
3. ✅ Implement `create_schema()` - Table creation
4. ⏳ Implement User CRUD operations:
   - `create_user()`
   - `get_user()`
   - `get_user_by_username()`
   - `update_user_karma()`
   - `username_exists()`
5. ⏳ Implement Subreddit CRUD operations:
   - `create_subreddit()`
   - `get_subreddit()`
   - `join_subreddit()` (junction table)
   - `leave_subreddit()` (junction table)
   - `get_user_subreddits()`
   - `get_subreddit_members()`
6. ⏳ Implement Post CRUD operations:
   - `create_post()`
   - `get_post()`
   - `get_subreddit_posts()`
   - `vote_post()`
   - `get_posts_for_feed()`
7. ⏳ Implement Comment CRUD operations:
   - `create_comment()`
   - `get_comment()`
   - `get_post_comments()`
   - `get_comment_replies()`
   - `vote_comment()`
8. ⏳ Implement Message CRUD operations:
   - `create_message()`
   - `get_message()`
   - `get_user_messages()`
   - `reply_to_message()`
   - `get_message_replies()`

### Phase 2: Engine Refactor
**File**: `src/reddit_engine/engine.gleam`

**Tasks**:
1. Update `EngineState` to include Database
2. Update `start()` to:
   - Connect to database
   - Create schema (if needed)
3. Refactor all message handlers:
   - `handle_register_user()` - Use `database.create_user()`
   - `handle_get_user()` - Use `database.get_user()`
   - `handle_create_subreddit()` - Use `database.create_subreddit()`
   - `handle_join_subreddit()` - Use `database.join_subreddit()`
   - `handle_leave_subreddit()` - Use `database.leave_subreddit()`
   - `handle_create_post()` - Use `database.create_post()`
   - `handle_vote_post()` - Use `database.vote_post()` + `database.update_user_karma()`
   - `handle_create_comment()` - Use `database.create_comment()`
   - `handle_vote_comment()` - Use `database.vote_comment()` + `database.update_user_karma()`
   - `handle_get_feed()` - Use `database.get_posts_for_feed()`
   - `handle_send_message()` - Use `database.create_message()`
   - `handle_reply_message()` - Use `database.reply_to_message()`
   - `handle_get_messages()` - Use `database.get_user_messages()`

### Phase 3: Connection Management
**Tasks**:
1. Implement connection pooling (pog handles this)
2. Add connection retry logic
3. Add connection health checks
4. Handle connection errors gracefully

### Phase 4: Transaction Support
**Tasks**:
1. Add transactions for multi-step operations
2. Ensure atomicity for operations like:
   - Creating post + updating subreddit_posts
   - Voting + updating karma
   - Creating comment + updating parent

### Phase 5: Testing & Migration
**Tasks**:
1. Unit tests for database operations
2. Integration tests with test database
3. Performance testing (compare dict vs database)
4. Data migration script (if needed for existing data)

---

## Code Structure

### New Files to Create

```
src/reddit_engine/
├── database.gleam          # Database abstraction layer (IN PROGRESS)
├── database_users.gleam    # User-specific database operations
├── database_subreddits.gleam  # Subreddit-specific operations
├── database_posts.gleam    # Post-specific operations
├── database_comments.gleam # Comment-specific operations
├── database_messages.gleam # Message-specific operations
└── migrations.gleam        # Database migration utilities
```

**OR** (simpler approach - all in one file):
```
src/reddit_engine/
└── database.gleam          # All database operations (STARTED)
```

---

## Dependencies

### Already Added to `gleam.toml`:
```toml
pog = ">= 4.0.0 and < 5.0.0"
```

### Required but may need additional setup:
- PostgreSQL client libraries (handled by pog)
- Connection pooling (handled by pog)

---

## Environment Configuration

### Environment Variables
```bash
# Database connection string
export DATABASE_URL="postgresql://user:password@localhost:5432/reddit_clone"

# Or individual components
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=reddit_clone
export PGUSER=postgres
export PGPASSWORD=your_password
```

### Configuration File Alternative
Create `config/database.toml` or use environment variables.

---

## Migration Strategy

### Option 1: Big Bang Migration
- Replace all dict operations at once
- Requires complete testing
- Higher risk, faster completion

### Option 2: Incremental Migration
- Migrate one feature at a time
- Start with users, then subreddits, then posts, etc.
- Lower risk, takes longer
- Can test each component separately

### Option 3: Hybrid Approach (Recommended)
- Add feature flag: `USE_DATABASE` environment variable
- Keep dict implementation as fallback
- Gradually migrate features
- Test with both implementations

---

## Testing Strategy

### Unit Tests
- Test each database operation independently
- Mock database connection if needed
- Test error handling

### Integration Tests
- Use test database
- Test full workflows (register → create subreddit → post → comment → vote)
- Test concurrent operations

### Performance Tests
- Compare dict vs database performance
- Load testing with many concurrent requests
- Measure query execution time

---

## Rollback Plan

### If Migration Fails
1. Keep dict-based implementation as fallback
2. Use feature flag to switch between implementations
3. Database errors fall back to dict (graceful degradation)
4. Or revert to dict-only if database causes issues

---

## Performance Considerations

### Optimizations Needed
1. **Connection Pooling**: Already handled by pog
2. **Query Optimization**: Add indexes on frequently queried columns
3. **Batch Operations**: For bulk inserts (user registration)
4. **Caching**: Consider Redis for frequently accessed data
5. **Lazy Loading**: Load related data on-demand (comments, replies)

### Expected Performance
- Database queries may be slower than dict lookups
- But can handle much larger datasets
- Better scalability for thousands/millions of records

---

## Documentation Updates Needed

1. **README.md**: Update setup instructions
2. **DATABASE_SETUP.md**: Database installation guide (CREATED)
3. **DATABASE_MIGRATION_NOTES.md**: Current status notes (CREATED)
4. **DEPLOYMENT.md**: Production deployment guide

---

## Timeline Estimate

### Minimum Viable Migration (MVP)
- Database module with basic CRUD: **4-6 hours**
- Engine refactor: **6-8 hours**
- Testing: **2-3 hours**
- **Total: 12-17 hours**

### Complete Production-Ready Migration
- Full database module: **8-12 hours**
- Engine refactor: **8-10 hours**
- Transactions & error handling: **3-4 hours**
- Testing & optimization: **4-6 hours**
- Documentation: **2-3 hours**
- **Total: 25-35 hours**

---

## Risks & Challenges

### Technical Risks
1. **API Compatibility**: pog API may differ from expectations
2. **Connection Management**: Handling disconnections, retries
3. **Transaction Management**: Ensuring data consistency
4. **Performance**: Database may be slower than dict for small datasets

### Migration Risks
1. **Breaking Changes**: Existing code may break
2. **Data Loss**: During migration if not careful
3. **Testing Gaps**: May miss edge cases
4. **Rollback Complexity**: Hard to revert once fully migrated

---

## Success Criteria

### Must Have
- ✅ All existing functionality works with database
- ✅ Data persists across restarts
- ✅ Performance acceptable (within 2x of dict)
- ✅ All tests pass
- ✅ No data loss during migration

### Nice to Have
- ✅ Performance better than dict for large datasets
- ✅ Connection pooling working efficiently
- ✅ Transaction support for complex operations
- ✅ Migration scripts for existing data

---

## Next Steps (When Ready)

1. **Install Prerequisites**
   ```bash
   # Install PostgreSQL
   # Install rebar3
   # Verify installations
   ```

2. **Set Up Development Database**
   ```bash
   createdb reddit_clone_dev
   export DATABASE_URL="postgresql://localhost/reddit_clone_dev"
   ```

3. **Complete Database Module**
   - Finish all CRUD operations in `database.gleam`
   - Add error handling
   - Add transaction support

4. **Refactor Engine**
   - Update EngineState
   - Replace all dict operations
   - Test each handler

5. **Integration Testing**
   - Run full simulator
   - Verify all metrics
   - Performance comparison

6. **Documentation**
   - Update README
   - Add deployment guide
   - Update performance report

---

## Notes

- **Current Implementation Works**: The dict-based approach fully meets Part I requirements
- **Database is Enhancement**: Adds production-readiness, not required for Part I
- **Can Coexist**: Both implementations can exist with feature flag
- **Future Work**: Part II (REST API/WebSockets) would benefit from database

---

## References

- Pog Library: https://hexdocs.pm/pog/
- PostgreSQL Docs: https://www.postgresql.org/docs/
- Gleam Database Guide: https://nulltree.xyz/articles/basic-postgres-setup-in-gleam/

---

**Last Updated**: 2025
**Status**: Planning Phase
**Assigned To**: Future implementation
**Priority**: Medium (enhancement, not requirement)

