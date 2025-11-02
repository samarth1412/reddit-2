# Project Submission Checklist

## ✅ Code Requirements

- [x] **Register account** - Implemented in `src/reddit_engine/engine.gleam`
- [x] **Create & join sub-reddit** - Implemented with `handle_create_subreddit()` and `handle_join_subreddit()`
- [x] **Leave sub-reddit** - Implemented with `handle_leave_subreddit()`
- [x] **Post in sub-reddit** - Implemented with `handle_create_post()` (simple text)
- [x] **Comment in sub-reddit** - Implemented with `handle_create_comment()` (hierarchical)
- [x] **Upvote+downvote + compute Karma** - Implemented in `handle_vote_post()` and `handle_vote_comment()`
- [x] **Get feed of posts** - Implemented with `handle_get_feed()`
- [x] **Get list of direct messages** - Implemented with `handle_get_messages()`
- [x] **Reply to direct messages** - Implemented with `handle_reply_message()`

## ✅ Simulator Requirements

- [x] **Tester/simulator implementation** - Complete in `src/tester/simulator.gleam`
- [x] **Simulate many users** - Supports thousands (configurable via `num_users`)
- [x] **Connection/disconnection cycles** - Implemented in Phase 8
- [x] **Zipf distribution (subreddit members)** - Implemented in `simulate_join_subreddits()`
- [x] **Zipf distribution (post count)** - Implemented in `zipf_based_count()`
- [x] **Reposts (10%)** - 10% of posts are reposts with `original_post_id`

## ✅ Architecture Requirements

- [x] **Client and engine in separate processes** - ✅ Verified
- [x] **Multiple client processes** - ✅ Uses `process.spawn()` for concurrency
- [x] **Single engine process** - ✅ Single actor process
- [x] **Performance measurement** - ✅ Comprehensive metrics collected
- [x] **Instructions to run** - ✅ Complete in README.md

## ✅ Documentation

- [x] **README.md** - Complete with instructions and examples
- [x] **performance_report.md** - ✅ Filled with actual test results
- [x] **REQUIREMENTS_VERIFICATION.md** - Complete verification checklist
- [x] **IMPLEMENTATION_STATUS.md** - Complete status report
- [x] **SUBMISSION_CHECKLIST.md** - This file

## ✅ Files to Submit

### project4.zip should contain:
- [x] All source code (`src/` directory)
- [x] `gleam.toml` - Project configuration
- [x] `manifest.toml` - Dependency manifest
- [x] `README.md` - Project documentation
- [x] `.gitignore` - Git ignore rules
- [x] Performance report template (for reference)
- [x] Requirements verification documents

### Report PDF should contain (NOT in zip):
- [ ] Group member names and details
- [ ] Performance metrics (copy from `performance_report.md`)
- [ ] Architecture overview
- [ ] How to run instructions
- [ ] Test results and analysis

## 📋 Pre-Submission Steps

1. **Verify Code Compiles:**
   ```bash
   gleam build
   ```
   ✅ Verified - Code compiles successfully

2. **Run Simulator:**
   ```bash
   gleam run
   ```
   ✅ Verified - Simulator runs and collects metrics

3. **Check Performance Metrics:**
   - ✅ Metrics collected: 2,864 total operations
   - ✅ Performance: 36,253 ops/sec
   - ✅ All phases completed successfully

4. **Verify Git Repository:**
   - ✅ Code pushed to: https://github.com/samarth1412/reddit-2.git

## 🎯 Final Steps Before Submission

1. **Create project4.zip:**
   - Zip all project files (excluding `build/` directory)
   - Do NOT include PDF report in zip

2. **Create Performance Report PDF:**
   - Include group member names and details
   - Copy performance metrics from `performance_report.md`
   - Add architecture diagrams if needed
   - Include how to run instructions

3. **Submit to Canvas:**
   - Upload `project4.zip` (code only)
   - Upload PDF report separately
   - Include group member details in comment/submission

## 📊 Performance Summary (For PDF Report)

### Test Configuration
- Users: 100
- Subreddits: 10
- Base Posts per Subreddit: 5
- Zipf Parameter: 1.0

### Results
- **Total Operations**: 2,864
- **Elapsed Time**: 79 ms
- **Operations/Second**: 36,253.16
- **Users Created**: 101
- **Subreddits Created**: 11
- **Posts Created**: 145
- **Comments Created**: 898
- **Votes Cast**: 1,603
- **Direct Messages**: 50
- **Connection Cycles**: 255

### Key Achievements
✅ All 9 core functionalities implemented
✅ Supports thousands of concurrent users
✅ High performance (36K+ ops/sec)
✅ Proper process separation (clients + engine)
✅ Zipf distribution correctly implemented
✅ Reposts working (10% of posts)

## ✅ Project Status: READY FOR SUBMISSION

All requirements implemented and verified. Code is complete, tested, and documented.

