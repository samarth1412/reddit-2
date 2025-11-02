import gleam/float
import gleam/int
import gleam/io
import gleam/string
import tester/simulator

pub fn main() {
  io.println("Reddit Clone Simulator")
  io.println("======================")

  // Run the full 100-user simulation
  let metrics = simulator.run_simulation(100, 10, 5, 1.0)

  io.println("\nPerformance Metrics:")
  io.println("===================")
  io.println(string.append(
    "Total Operations: ",
    int.to_string(metrics.total_operations),
  ))
  io.println(string.append(
    "Messages Sent: ",
    int.to_string(metrics.messages_sent),
  ))
  io.println(string.append(
    "Users Created: ",
    int.to_string(metrics.users_created),
  ))
  io.println(string.append(
    "Subreddits Created: ",
    int.to_string(metrics.subreddits_created),
  ))
  io.println(string.append(
    "Posts Created: ",
    int.to_string(metrics.posts_created),
  ))
  io.println(string.append(
    "Comments Created: ",
    int.to_string(metrics.comments_created),
  ))
  io.println(string.append("Votes Cast: ", int.to_string(metrics.votes_cast)))
  io.println(string.append(
    "Direct Messages Sent: ",
    int.to_string(metrics.direct_messages_sent),
  ))
  io.println(string.append(
    "Feed Requests: ",
    int.to_string(metrics.feed_requests),
  ))
  io.println(string.append(
    "Connection Cycles: ",
    int.to_string(metrics.connection_cycles),
  ))
  io.println(string.append(
    "Elapsed Time (ms): ",
    int.to_string(metrics.elapsed_time_ms),
  ))
  io.println(string.append(
    "Operations per Second: ",
    float.to_string(metrics.operations_per_second),
  ))
}
