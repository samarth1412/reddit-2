# Reddit Clone Performance Report

## Overview
This report contains performance metrics from running the Reddit Clone simulator.

## Test Configuration

### Simulation Parameters
- Number of Users: [To be filled after running tests]
- Number of Subreddits: [To be filled]
- Posts per Subreddit (base): [To be filled]
- Zipf Distribution Parameter: [To be filled]
- Simulation Duration: [To be filled]

## Performance Metrics

### Operations
- Total Operations: [To be filled]
- Messages Sent: [To be filled]
- Users Created: [To be filled]
- Subreddits Created: [To be filled]
- Posts Created: [To be filled]
- Comments Created: [To be filled]
- Votes Cast: [To be filled]
- Direct Messages Sent: [To be filled]
- Feed Requests: [To be filled]
- Connection Cycles: [To be filled]

### Timing
- Total Elapsed Time (ms): [To be filled]
- Operations per Second: [To be filled]
- Average Response Time (ms): [To be filled]

### Distribution Analysis
- Subreddit Membership Distribution: [To be filled]
  - Top 10% of subreddits have X% of members
  - Zipf distribution verification

### Connection Patterns
- Connection/Disconnection Cycles: [To be filled]
- Users Simulated with Connection Cycles: [To be filled]
- Activities per Connection Cycle: 2-5 random activities
  - Feed fetching
  - Message checking/sending
  - Post voting

## How to Generate This Report

1. Run the simulator:
   ```bash
   gleam run -m tester
   ```

2. Collect metrics from the console output

3. Update this report with the actual values

## Notes

- The simulator uses Zipf distribution to model real-world patterns where popular subreddits have more members and posts
- Connection/disconnection patterns simulate real client behavior
- Performance may vary based on system resources

