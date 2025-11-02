import gleam/erlang/atom.{type Atom}

/// Small compatibility shim to expose a minimal subset of Erlang calls
/// used throughout the project as `erlang.system_time(...)` and
/// `erlang.sleep(...)`.
pub fn millisecond() -> Atom {
  atom.create("millisecond")
}

@external(erlang, "erlang", "system_time")
pub fn system_time(unit: Atom) -> Int

@external(erlang, "erlang", "sleep")
pub fn sleep(ms: Int) -> Nil
