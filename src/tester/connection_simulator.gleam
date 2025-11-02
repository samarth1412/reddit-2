import client/api
import erlang_helper as erlang
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/time/timestamp
import prng/random as prng_random
import prng/seed as prng_seed
import reddit_engine/types

pub type ConnectionState {
  Connected
  Disconnected
}

pub type SimulatedClient {
  SimulatedClient(
    client: api.Client,
    user_id: Option(types.UserId),
    state: ConnectionState,
    connected_at: Int,
    disconnected_at: Int,
    operations_performed: Int,
  )
}

// Simulate connection/disconnection cycles
pub fn simulate_client_lifecycle(
  client_api: api.Client,
  user_id: types.UserId,
  duration_ms: Int,
) -> Int {
  // compute start time in milliseconds using gleam_time
  let ts = timestamp.system_time()
  let #(secs, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  let nanos_ms = case int.divide(nanos, 1_000_000) {
    Ok(v) -> v
    Error(_) -> 0
  }
  let start_ms = secs * 1000 + nanos_ms
  simulate_loop(client_api, user_id, True, start_ms, duration_ms, 0)
}

fn simulate_loop(
  client_api: api.Client,
  user_id: types.UserId,
  is_connected: Bool,
  start_time: Int,
  duration_ms: Int,
  operations: Int,
) -> Int {
  let ts_now = timestamp.system_time()
  let #(secs_now, nanos_now) = timestamp.to_unix_seconds_and_nanoseconds(ts_now)
  let nanos_now_ms = case int.divide(nanos_now, 1_000_000) {
    Ok(v) -> v
    Error(_) -> 0
  }
  let current_time = secs_now * 1000 + nanos_now_ms
  let elapsed = current_time - start_time

  case elapsed >= duration_ms {
    True -> operations
    False -> {
      case is_connected {
        True -> {
          let new_ops = simulate_user_activity(client_api, user_id)
          erlang.sleep(100)
          simulate_loop(
            client_api,
            user_id,
            True,
            start_time,
            duration_ms,
            operations + new_ops,
          )
        }
        False -> {
          erlang.sleep(100)
          simulate_loop(
            client_api,
            user_id,
            False,
            start_time,
            duration_ms,
            operations,
          )
        }
      }
    }
  }
}

fn simulate_user_activity(client_api: api.Client, user_id: types.UserId) -> Int {
  // deterministic pick between feed or messages
  let ts = timestamp.system_time()
  let #(secs, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  let nanos_ms = case int.divide(nanos, 1_000_000) {
    Ok(v) -> v
    Error(_) -> 0
  }
  let seed = secs * 1000 + nanos_ms
  let activity_type =
    prng_random.sample(prng_random.int(0, 1), prng_seed.new(seed))

  case activity_type {
    0 -> {
      case api.get_feed(client_api, user_id, 10) {
        Ok(_) -> 1
        Error(_) -> 0
      }
    }
    _ -> {
      case api.get_messages(client_api, user_id) {
        Ok(_) -> 1
        Error(_) -> 0
      }
    }
  }
}

pub fn run_connection_simulation(
  clients: List(api.Client),
  user_ids: List(types.UserId),
  duration_ms: Int,
) -> Int {
  let total_operations =
    list.fold(list.zip(clients, user_ids), 0, fn(acc, pair) {
      case pair {
        #(client, user_id) -> {
          let ops = simulate_client_lifecycle(client, user_id, duration_ms)
          acc + ops
        }
      }
    })
  total_operations
}
