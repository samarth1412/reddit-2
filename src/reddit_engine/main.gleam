import gleam/io
import reddit_engine/engine

pub fn main() {
  io.println("Reddit Engine Started")
  io.println("Engine process is running...")
  let _engine = engine.start()
  io.println("Engine is ready to accept messages")
  // Keep process alive
  loop()
}

fn loop() {
  loop()
}
