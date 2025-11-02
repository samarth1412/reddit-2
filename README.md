# Reddit Clone - Actor Model Implementation in Gleam

A distributed Reddit-like social media platform implemented using the actor model in Gleam. This project demonstrates a distributed system with a single engine process handling requests from multiple client processes.

## Project Structure

```
.
├── src/
│   ├── reddit_engine/          # Core engine implementation with actors
│   │   ├── types.gleam         # Data types and message definitions
│   │   ├── engine.gleam        # Main engine actor implementation
│   │   └── main.gleam          # Engine entry point
│   ├── client/                 # Client API wrapper
│   │   └── api.gleam           # Client API functions
│   └── tester/                 # Test simulator with performance metrics
│       ├── simulator.gleam     # Main simulation logic with Zipf distribution
│       ├── connection_simulator.gleam  # Connection/disconnection simulation
│       └── main.gleam          # Simulator entry point
├── gleam.toml                  # Project configuration
├── README.md                   # This file
└── performance_report.md       # Performance metrics template
```

## Features

### Core Functionality
- ✅ User registration and management
- ✅ Sub-reddit creation, joining, and leaving
- ✅ Posting and commenting (hierarchical comments)
- ✅ Upvote/downvote with karma calculation
- ✅ Feed generation from subscribed sub-reddits
- ✅ Direct messaging with reply support
- ✅ Repost functionality (10% of posts)

### Architecture
- **Actor Model**: Single engine process using Gleam's actor model (process-based concurrency)
- **Message Passing**: All operations use asynchronous message passing
- **Separation of Concerns**: Engine and clients are in separate processes

### Simulator Features
- ✅ Multiple simulated users (configurable)
- ✅ Connection/disconnection simulation (users periodically disconnect/reconnect)
- ✅ Zipf distribution for sub-reddit membership (popular sub-reddits have more members)
- ✅ Zipf-based post distribution (popular sub-reddits get more posts)
- ✅ Performance metrics collection
- ✅ Random user activities (feed fetching, messaging, etc.)

## Requirements

- **Gleam**: 0.32 or later
- **Erlang/OTP**: 24 or later

Install Gleam from: https://gleam.run/getting-started/

## Building

```bash
gleam build
```

## Running

### Run the Main Simulator

The main simulator creates users, sub-reddits, posts, comments, and votes, then reports performance metrics:

```bash
gleam run -m tester
```

This will:
1. Register users (concurrently)
2. Create sub-reddits
3. Users join sub-reddits (Zipf distribution - popular subreddits have more members)
4. Create posts (more posts in popular sub-reddits via Zipf, 10% are reposts)
5. Create comments (hierarchical)
6. Cast votes on posts
7. Send direct messages
8. Simulate connection/disconnection cycles with random activities (feed fetching, messaging, voting)
9. Report comprehensive performance metrics

### Run the Engine Standalone

To run just the engine (for testing or integration):

```bash
gleam run -m reddit_engine/main
```

## Configuration

You can modify simulation parameters in `src/tester/main.gleam`:

```gleam
let metrics = simulator.run_simulation(
  num_users: 100,        // Number of users to simulate
  num_subreddits: 10,    // Number of sub-reddits to create
  posts_per_subreddit: 5, // Base number of posts per sub-reddit (before Zipf scaling)
  zipf_parameter: 1.0,   // Zipf distribution parameter (s) - higher = more skewed
)
```

**Note**: For testing with thousands of users, increase `num_users` accordingly. The simulator spawns concurrent client processes for scalability.

## Architecture Details

### Engine Actor

The engine is a single actor process that maintains:
- User registry
- Sub-reddit registry
- Posts and comments
- Direct messages
- Karma tracking

All operations are handled via message passing. The engine receives `EngineMessage` and responds with `EngineResponse`.

### Client API

The client API provides a synchronous interface for clients to interact with the engine:
- `register_user()` - Register a new user
- `create_subreddit()` - Create a sub-reddit
- `join_subreddit()` - Join a sub-reddit
- `create_post()` - Create a post (supports reposts)
- `create_comment()` - Create a comment (hierarchical)
- `vote_post()` / `vote_comment()` - Upvote or downvote
- `get_feed()` - Get personalized feed
- `send_message()` / `reply_to_message()` - Direct messaging
- `get_messages()` - Retrieve messages

### Zipf Distribution

The simulator uses Zipf distribution to model real-world patterns:
- **Sub-reddit Membership**: Popular sub-reddits (lower rank) have exponentially more members
- **Post Distribution**: Popular sub-reddits receive more posts
- **Formula**: P(rank) = 1/(rank^s), where s is the Zipf parameter

### Connection/Disconnection Simulation

The simulator models real client behavior with connection/disconnection cycles:
- Users spawn as independent client processes
- Each user cycles through connection and disconnection periods
- During connection periods, users perform random activities:
  - Fetch feed (view posts from subscribed subreddits)
  - Check direct messages
  - Send new direct messages
  - Vote on posts
- 2-3 connection cycles per simulated user
- Activities are performed concurrently by multiple client processes

## Performance Metrics

The simulator collects and reports:
- Total operations performed
- Users, sub-reddits, posts, comments created
- Votes cast
- Elapsed time
- Operations per second

Example output:
```
Reddit Clone Simulator
======================
Starting simulation...
Phase 1: Registering users...
Created 100 users
Phase 2: Creating subreddits...
Created 10 subreddits
Phase 3: Users joining subreddits...
Phase 4: Creating posts...
Created 50 posts
Phase 5: Creating comments...
Created 250 comments
Phase 6: Casting votes...
Cast 500 votes
Phase 7: Sending direct messages...
Sent 50 direct messages
Phase 8: Simulating connection/disconnection cycles...
Completed 150 connection cycles
Simulation completed in 2345 ms
Operations per second: 362.47

Performance Metrics:
===================
Total Operations: 850
Messages Sent: 850
Users Created: 100
Subreddits Created: 10
Posts Created: 50
Comments Created: 250
Votes Cast: 500
Direct Messages Sent: 50
Feed Requests: 100
Connection Cycles: 150
Elapsed Time (ms): 2345
Operations per Second: 362.47
```

## Testing

Run the test suite (if available):

```bash
gleam test
```

## Performance Report

After running the simulator, update `performance_report.md` with your results. The template includes sections for:
- Test configuration
- Operations metrics (posts, comments, votes, messages)
- Timing metrics (elapsed time, ops/sec)
- Distribution analysis (Zipf verification)
- Connection patterns (connection cycles, concurrent activities)

**To generate a report:**
1. Run the simulator: `gleam run -m tester`
2. Copy the metrics from the console output
3. Fill in `performance_report.md` with the actual values

## Implementation Notes

1. **Actor Model**: Uses Gleam's `gleam/otp/actor` for actor-based concurrency
2. **Message Passing**: All client-engine communication uses synchronous `process.call` with timeouts
3. **State Management**: Engine maintains all state in a single actor process (no shared memory)
4. **Concurrency**: Multiple client processes spawn concurrently for user registration and activities
5. **Zipf Distribution**: Popular subreddits (lower rank) get exponentially more members and posts
6. **Reposts**: 10% of posts are reposts, referencing original post IDs
7. **Connection Cycles**: Users simulate real-world behavior with connect/disconnect patterns
8. **Error Handling**: All operations return `Result` types for proper error handling

## Project Requirements Checklist

✅ Register account
✅ Create & join sub-reddit; leave sub-reddit
✅ Post in sub-reddit (simple text posts)
✅ Comment in sub-reddit (hierarchical comments)
✅ Upvote+downvote + compute Karma
✅ Get feed of posts
✅ Get list of direct messages; Reply to direct messages
✅ Implement a tester/simulator
✅ Simulate many users (configurable, supports thousands)
✅ Simulate periods of live connection and disconnection
✅ Simulate Zipf distribution on sub-reddit members
✅ Increase posts for popular sub-reddits
✅ Include reposts (10% of posts)
✅ Separate client and engine processes
✅ Measure and report performance metrics

## Future Enhancements

Possible improvements:
- Persistence layer (database integration)
- REST API wrapper around the engine
- WebSocket support for real-time updates
- Distributed engine (multiple engine processes)
- Load balancing
- Caching layer
- More sophisticated feed algorithms

## License

MIT

## Author

Reddit Clone Project - DOSP Assignment

