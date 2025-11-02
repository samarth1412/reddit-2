import client/api
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option

// result not needed here; removed to silence unused-import warning
import gleam/string
import gleam/time/timestamp
import prng/random as prng_random
import prng/seed as prng_seed
import reddit_engine/engine
import reddit_engine/types

// Helper: safe get by index using index_fold (returns option.Option(a))
fn get_at(list_x: List(a), idx: Int) -> option.Option(a) {
  list.index_fold(list_x, option.None, fn(acc, item, i) {
    case acc {
      option.Some(_) -> acc
      option.None ->
        case i == idx {
          True -> option.Some(item)
          False -> option.None
        }
    }
  })
}

pub type SimulatorState {
  SimulatorState(
    engine: api.Client,
    users: List(types.UserId),
    subreddits: List(types.SubredditId),
    posts: List(types.PostId),
    messages_sent: Int,
    operations_completed: Int,
    start_time: Int,
    connected_users: List(types.UserId),
  )
}

pub type PerformanceMetrics {
  PerformanceMetrics(
    total_operations: Int,
    messages_sent: Int,
    users_created: Int,
    subreddits_created: Int,
    posts_created: Int,
    comments_created: Int,
    votes_cast: Int,
    direct_messages_sent: Int,
    feed_requests: Int,
    connection_cycles: Int,
    elapsed_time_ms: Int,
    operations_per_second: Float,
  )
}

// Zipf distribution helper
// Returns weight based on rank for Zipf distribution
fn zipf_weight(rank: Int, s: Float) -> Float {
  // Zipf probability: P(rank) = 1/(rank^s * H(n,s))
  // For simplicity, we use 1/rank^s as weight
  let base = int.to_float(rank)
  case float.power(base, s) {
    Ok(p) -> 1.0 /. p
    Error(_) -> 0.0
  }
}

// Get number of members/posts based on Zipf distribution
fn zipf_based_count(
  index: Int,
  _num_items: Int,
  base_count: Int,
  s: Float,
) -> Int {
  let rank = index + 1
  let weight = zipf_weight(rank, s)
  // Higher rank (lower index) gets more members/posts
  let inv_exp = -1.0 /. s
  let multiplier = case float.power(weight, inv_exp) {
    Ok(m) -> m
    Error(_) -> 1.0
  }
  // Inverse relationship
  float.truncate(int.to_float(base_count) *. multiplier)
}

// Deterministic helpers using prng with an integer seed
fn det_int_range(from: Int, to: Int, seed_int: Int) -> Int {
  let seed = prng_seed.new(seed_int)
  prng_random.sample(prng_random.int(from, to), seed)
}

fn det_float_range(from: Float, to: Float, seed_int: Int) -> Float {
  let seed = prng_seed.new(seed_int)
  prng_random.sample(prng_random.float(from, to), seed)
}

// Simulate user registration
fn simulate_register_user(
  client: api.Client,
  username: String,
) -> Result(types.User, String) {
  api.register_user(client, username)
}

// Simulate subreddit creation
fn simulate_create_subreddit(
  client: api.Client,
  user_id: types.UserId,
  name: String,
) -> Result(types.Subreddit, String) {
  api.create_subreddit(client, user_id, name)
}

// Simulate joining subreddits with Zipf distribution
fn simulate_join_subreddits(
  client: api.Client,
  user_id: types.UserId,
  subreddits: List(types.SubredditId),
  seed: Int,
) -> Int {
  // Zipf distribution: join more popular subreddits with higher probability
  let num_to_join = det_int_range(1, list.length(subreddits), seed)
  let joined = list.take(subreddits, num_to_join)
  list.fold(joined, 0, fn(count, subreddit_id) {
    case api.join_subreddit(client, user_id, subreddit_id) {
      Ok(_) -> count + 1
      Error(_) -> count
    }
  })
}

// Simulate posting
fn simulate_post(
  client: api.Client,
  user_id: types.UserId,
  subreddit_id: types.SubredditId,
  _is_repost: Bool,
  original_post_id: option.Option(types.PostId),
  seed: Int,
) -> Result(types.Post, String) {
  let title = string.append("Post ", int.to_string(seed))
  let content = "This is a test post content"
  api.create_post(
    client,
    user_id,
    subreddit_id,
    title,
    content,
    original_post_id,
  )
}

// Simulate commenting
fn simulate_comment(
  client: api.Client,
  user_id: types.UserId,
  post_id: types.PostId,
  parent_comment_id: option.Option(types.CommentId),
  seed: Int,
) -> Result(types.Comment, String) {
  let content = string.append("Comment ", int.to_string(seed))
  api.create_comment(client, user_id, post_id, parent_comment_id, content)
}

// Simulate direct messaging
fn simulate_send_message(
  client: api.Client,
  from: types.UserId,
  to: types.UserId,
  seed: Int,
) -> Result(String, String) {
  let content = string.append("Message ", int.to_string(seed))
  api.send_message(client, from, to, content)
}

// Simulate random user activity during connection periods
fn simulate_random_activity(
  client: api.Client,
  user_id: types.UserId,
  posts: List(types.PostId),
  users: List(types.UserId),
  seed: Int,
) -> Int {
  let activity_type = det_int_range(0, 4, seed)
  case activity_type {
    0 -> {
      // Fetch feed
      case api.get_feed(client, user_id, 10) {
        Ok(_) -> 1
        Error(_) -> 0
      }
    }
    1 -> {
      // Get messages
      case api.get_messages(client, user_id) {
        Ok(_) -> 1
        Error(_) -> 0
      }
    }
    2 -> {
      // Send a direct message
      case list.length(users) > 1 {
        True -> {
          let recipient_index = det_int_range(0, list.length(users) - 1, seed + 100)
          let recipient = get_at(users, recipient_index)
          case recipient {
            option.Some(to) -> {
              case to != user_id {
                True -> {
                  case simulate_send_message(client, user_id, to, seed) {
                    Ok(_) -> 1
                    Error(_) -> 0
                  }
                }
                False -> 0
              }
            }
            option.None -> 0
          }
        }
        False -> 0
      }
    }
    3 -> {
      // Vote on a random post
      case list.length(posts) > 0 {
        True -> {
          let post_index = det_int_range(0, list.length(posts) - 1, seed + 200)
          let post = get_at(posts, post_index)
          case post {
            option.Some(post_id) -> {
              let vote_type = case det_int_range(0, 1, seed + 300) {
                0 -> types.Upvote
                _ -> types.Downvote
              }
              case api.vote_post(client, user_id, post_id, vote_type) {
                Ok(_) -> 1
                Error(_) -> 0
              }
            }
            option.None -> 0
          }
        }
        False -> 0
      }
    }
    _ -> 0
  }
}

pub fn run_simulation(
  num_users: Int,
  num_subreddits: Int,
  posts_per_subreddit: Int,
  zipf_parameter: Float,
) -> PerformanceMetrics {
  io.println("Starting simulation...")

  let engine_process = engine.start()
  let client = api.new(engine_process)

  // Use gleam_time timestamp for a stable wall-clock seed in milliseconds
  let ts = timestamp.system_time()
  let #(secs, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  let nanos_ms = case int.divide(nanos, 1_000_000) {
    Ok(v) -> v
    Error(_) -> 0
  }
  let start_time = secs * 1000 + nanos_ms
  let seed = start_time

  // Phase 1: Register users
  io.println("Phase 1: Registering users...")
  // Spawn concurrent client processes to register users and collect results
  let collector = process.new_subject()

  // Spawn registration jobs
  let _ =
    list.fold(list.range(0, num_users), Nil, fn(_, i) {
      let username = string.append("user_", int.to_string(i))
      let _pid =
        process.spawn(fn() {
          let local_client = api.new(engine_process)
          let res = simulate_register_user(local_client, username)
          // Send the Result back to the collector subject
          let _ = process.send(collector, res)
          Nil
        })
      Nil
    })

  // Collect registration results (with a simple timeout per receive)
  let users =
    list.fold(list.range(0, num_users), [], fn(acc, _) {
      case process.receive(from: collector, within: 5000) {
        Ok(response) -> {
          case response {
            Ok(user) -> list.append(acc, [user.id])
            Error(_) -> acc
          }
        }
        Error(_) -> acc
      }
    })

  let users_created = list.length(users)
  io.println(string.append(
    string.append("Created ", int.to_string(users_created)),
    " users",
  ))

  // Phase 2: Create subreddits with Zipf distribution
  io.println("Phase 2: Creating subreddits...")
  let subreddits =
    list.range(0, num_subreddits)
    |> list.map(fn(i) {
      case list.length(users) > 0 {
        True -> {
          let creator_index = det_int_range(0, list.length(users) - 1, seed + i)
          let creator = get_at(users, creator_index)
          case creator {
            option.Some(user_id) -> {
              let subreddit_name = string.append("subreddit_", int.to_string(i))
              case simulate_create_subreddit(client, user_id, subreddit_name) {
                Ok(subreddit) -> Ok(subreddit.id)
                Error(e) -> Error(e)
              }
            }
            option.None -> Error("No creator found")
          }
        }
        False -> Error("No users available")
      }
    })
    |> list.filter_map(fn(r) { r })

  let subreddits_created = list.length(subreddits)
  io.println(string.append(
    string.append("Created ", int.to_string(subreddits_created)),
    " subreddits",
  ))

  // Phase 3: Users join subreddits (Zipf distribution)
  io.println("Phase 3: Users joining subreddits...")
  let _ =
    list.fold(users, 0, fn(acc, user_id) {
      let join_count =
        simulate_join_subreddits(client, user_id, subreddits, seed + acc)
      acc + join_count
    })

  // Phase 4: Create posts (more posts in popular subreddits)
  io.println("Phase 4: Creating posts...")
  let posts =
    list.index_fold(subreddits, [], fn(acc, subreddit_id, subreddit_index) {
      // Popular subreddits get more posts (Zipf distribution)
      let posts_for_subreddit =
        zipf_based_count(
          subreddit_index,
          list.length(subreddits),
          posts_per_subreddit,
          zipf_parameter,
        )

      let posts_in_subreddit =
        list.fold(list.range(0, posts_for_subreddit), acc, fn(acc2, i) {
          case list.length(users) > 0 {
            True -> {
              let author_index =
                det_int_range(0, list.length(users) - 1, seed + i)
              let author = get_at(users, author_index)
              case author {
                option.Some(user_id) -> {
                  let is_repost = det_float_range(0.0, 1.0, seed + i) <. 0.1
                  let original_post = case is_repost {
                    True -> {
                      case list.length(acc2) > 0 {
                        True -> {
                          let post_index =
                            det_int_range(
                              0,
                              list.length(acc2) - 1,
                              seed + i + 1000,
                            )
                          get_at(acc2, post_index)
                        }
                        False -> option.None
                      }
                    }
                    False -> option.None
                  }
                  case
                    simulate_post(
                      client,
                      user_id,
                      subreddit_id,
                      is_repost,
                      original_post,
                      seed + i,
                    )
                  {
                    Ok(post) -> list.append(acc2, [post.id])
                    Error(_) -> acc2
                  }
                }
                option.None -> acc2
              }
            }
            False -> acc2
          }
        })
      posts_in_subreddit
    })

  let posts_created = list.length(posts)
  io.println(string.append(
    string.append("Created ", int.to_string(posts_created)),
    " posts",
  ))

  // Phase 5: Create comments
  io.println("Phase 5: Creating comments...")
  let comments_created =
    list.fold(posts, 0, fn(acc, post_id) {
      let num_comments = det_int_range(0, 10, seed + acc)
      let added =
        list.fold(list.range(0, num_comments), 0, fn(acc2, i) {
          case list.length(users) > 0 {
            True -> {
              let commenter_index =
                det_int_range(0, list.length(users) - 1, seed + acc2 + i)
              let commenter = get_at(users, commenter_index)
              case commenter {
                option.Some(user_id) -> {
                  case
                    simulate_comment(
                      client,
                      user_id,
                      post_id,
                      option.None,
                      seed + acc2 + i,
                    )
                  {
                    Ok(_) -> acc2 + 1
                    Error(_) -> acc2
                  }
                }
                option.None -> acc2
              }
            }
            False -> acc2
          }
        })
      acc + added
    })
  io.println(string.append(
    string.append("Created ", int.to_string(comments_created)),
    " comments",
  ))

  // Phase 6: Voting
  io.println("Phase 6: Casting votes...")
  let votes_cast =
    list.fold(posts, 0, fn(acc, post_id) {
      let num_votes = det_int_range(0, 20, seed + acc)
      let added =
        list.fold(list.range(0, num_votes), 0, fn(acc2, i) {
          case list.length(users) > 0 {
            True -> {
              let voter_index =
                det_int_range(0, list.length(users) - 1, seed + acc2 + i)
              let voter = get_at(users, voter_index)
              case voter {
                option.Some(user_id) -> {
                  let vote_type = case det_int_range(0, 1, seed + acc2 + i) {
                    0 -> types.Upvote
                    _ -> types.Downvote
                  }
                  case api.vote_post(client, user_id, post_id, vote_type) {
                    Ok(_) -> acc2 + 1
                    Error(_) -> acc2
                  }
                }
                option.None -> acc2
              }
            }
            False -> acc2
          }
        })
      acc + added
    })
  io.println(string.append(
    string.append("Cast ", int.to_string(votes_cast)),
    " votes",
  ))

  // Phase 7: Direct messaging
  io.println("Phase 7: Sending direct messages...")
  let num_messages = case int.divide(users_created, 2) {
    Ok(v) -> v
    Error(_) -> 0
  }
  let direct_messages_sent =
    list.fold(list.range(0, num_messages), 0, fn(acc, i) {
      case list.length(users) > 1 {
        True -> {
          let sender_index = det_int_range(0, list.length(users) - 1, seed + i + 5000)
          let sender = get_at(users, sender_index)
          case sender {
            option.Some(sender_id) -> {
              let recipient_index =
                det_int_range(0, list.length(users) - 1, seed + i + 6000)
              let recipient = get_at(users, recipient_index)
              case recipient {
                option.Some(recipient_id) -> {
                  case sender_id != recipient_id {
                    True -> {
                      case simulate_send_message(client, sender_id, recipient_id, seed + i) {
                        Ok(_) -> acc + 1
                        Error(_) -> acc
                      }
                    }
                    False -> acc
                  }
                }
                option.None -> acc
              }
            }
            option.None -> acc
          }
        }
        False -> acc
      }
    })
  io.println(string.append(
    string.append("Sent ", int.to_string(direct_messages_sent)),
    " direct messages",
  ))

  // Phase 8: Simulate connection/disconnection cycles with random activities
  io.println("Phase 8: Simulating connection/disconnection cycles...")
  let activity_collector = process.new_subject()
  let connection_collector = process.new_subject()
  
  // Spawn concurrent client processes that simulate connection/disconnection
  // Simulate connection cycles for all users (supports thousands)
  let num_activity_cycles = users_created
  let _ =
    list.fold(
      users,
      0,
      fn(acc, user_id) {
        let _pid =
          process.spawn(fn() {
            let local_client = api.new(engine_process)
            let cycle_seed = seed + acc + 7000
            
            // Simulate 2-3 connection cycles per user
            let num_cycles = det_int_range(2, 3, cycle_seed)
            let cycles_completed =
              list.fold(list.range(0, num_cycles - 1), 0, fn(cycle_count, _) {
                // Simulate connected period: perform random activities
                let activities_in_cycle = det_int_range(2, 5, cycle_seed + cycle_count)
                let activity_ops =
                  list.fold(list.range(0, activities_in_cycle - 1), 0, fn(ops, a) {
                    ops + simulate_random_activity(
                      local_client,
                      user_id,
                      posts,
                      users,
                      cycle_seed + cycle_count + a,
                    )
                  })
                let _ = process.send(activity_collector, activity_ops)
                cycle_count + 1
              })
            let _ = process.send(connection_collector, cycles_completed)
            Nil
          })
        acc + 1
      },
    )

  // Collect activity results
  let feed_requests =
    list.fold(list.range(0, num_activity_cycles - 1), 0, fn(acc, _) {
      case process.receive(from: activity_collector, within: 10000) {
        Ok(ops) -> acc + ops
        Error(_) -> acc
      }
    })

  // Collect connection cycle results
  let connection_cycles =
    list.fold(list.range(0, num_activity_cycles - 1), 0, fn(acc, _) {
      case process.receive(from: connection_collector, within: 10000) {
        Ok(cycles) -> acc + cycles
        Error(_) -> acc
      }
    })

  io.println(string.append(
    string.append("Completed ", int.to_string(connection_cycles)),
    " connection cycles",
  ))

  // Use gleam_time to compute end time in ms (consistent with start_time)
  let ts2 = timestamp.system_time()
  let #(secs2, nanos2) = timestamp.to_unix_seconds_and_nanoseconds(ts2)
  let nanos2_ms = case int.divide(nanos2, 1_000_000) {
    Ok(v) -> v
    Error(_) -> 0
  }
  let end_time = secs2 * 1000 + nanos2_ms
  let elapsed_time_ms = end_time - start_time
  let elapsed_time_sec = int.to_float(elapsed_time_ms) /. 1000.0
  let total_ops =
    posts_created + comments_created + votes_cast + direct_messages_sent + feed_requests
  let operations_per_second = int.to_float(total_ops) /. elapsed_time_sec

  io.println(string.append(
    string.append("Simulation completed in ", int.to_string(elapsed_time_ms)),
    " ms",
  ))
  io.println(string.append(
    "Operations per second: ",
    float.to_string(operations_per_second),
  ))

  PerformanceMetrics(
    total_operations: total_ops,
    messages_sent: posts_created + comments_created + votes_cast + direct_messages_sent,
    users_created: users_created,
    subreddits_created: subreddits_created,
    posts_created: posts_created,
    comments_created: comments_created,
    votes_cast: votes_cast,
    direct_messages_sent: direct_messages_sent,
    feed_requests: feed_requests,
    connection_cycles: connection_cycles,
    elapsed_time_ms: elapsed_time_ms,
    operations_per_second: operations_per_second,
  )
}
