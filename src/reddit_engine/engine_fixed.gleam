// engine_fixed.gleam intentionally removed to avoid duplicate engine implementations
// during actor-model migration. The actor-based implementation lives in
// `src/reddit_engine/engine.gleam`.

// Keep a tiny public stub so other modules importing this file won't fail.
pub fn engine_fixed_removed() -> Nil {
    Nil
}
