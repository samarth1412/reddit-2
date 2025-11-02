import gleam/erlang/process
import gleam/option.{type Option}
import reddit_engine/types

pub type Client {
  Client(engine: process.Subject(types.EngineMessage))
}

pub fn new(engine: process.Subject(types.EngineMessage)) -> Client {
  Client(engine)
}

fn get_engine(client: Client) -> process.Subject(types.EngineMessage) {
  case client {
    Client(engine) -> engine
  }
}

pub fn register_user(
  client: Client,
  username: String,
) -> Result(types.User, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) { types.RegisterUser(username, reply) })
  case response {
    types.UserResponse(user) -> Ok(user)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn get_user(
  client: Client,
  user_id: types.UserId,
) -> Result(types.User, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) { types.GetUser(user_id, reply) })
  case response {
    types.UserResponse(user) -> Ok(user)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn create_subreddit(
  client: Client,
  user_id: types.UserId,
  name: String,
) -> Result(types.Subreddit, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.CreateSubreddit(user_id, name, reply)
    })
  case response {
    types.SubredditResponse(subreddit) -> Ok(subreddit)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn join_subreddit(
  client: Client,
  user_id: types.UserId,
  subreddit_id: types.SubredditId,
) -> Result(String, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.JoinSubreddit(user_id, subreddit_id, reply)
    })
  case response {
    types.Success(msg) -> Ok(msg)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn leave_subreddit(
  client: Client,
  user_id: types.UserId,
  subreddit_id: types.SubredditId,
) -> Result(String, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.LeaveSubreddit(user_id, subreddit_id, reply)
    })
  case response {
    types.Success(msg) -> Ok(msg)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn create_post(
  client: Client,
  user_id: types.UserId,
  subreddit_id: types.SubredditId,
  title: String,
  content: String,
  original_post_id: Option(types.PostId),
) -> Result(types.Post, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.CreatePost(
        user_id,
        subreddit_id,
        title,
        content,
        original_post_id,
        reply,
      )
    })
  case response {
    types.PostResponse(post) -> Ok(post)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn vote_post(
  client: Client,
  user_id: types.UserId,
  post_id: types.PostId,
  vote_type: types.VoteType,
) -> Result(String, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.VotePost(user_id, post_id, vote_type, reply)
    })
  case response {
    types.Success(msg) -> Ok(msg)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn create_comment(
  client: Client,
  user_id: types.UserId,
  post_id: types.PostId,
  parent_comment_id: Option(types.CommentId),
  content: String,
) -> Result(types.Comment, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.CreateComment(user_id, post_id, parent_comment_id, content, reply)
    })
  case response {
    types.CommentResponse(comment) -> Ok(comment)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn vote_comment(
  client: Client,
  user_id: types.UserId,
  comment_id: types.CommentId,
  vote_type: types.VoteType,
) -> Result(String, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.VoteComment(user_id, comment_id, vote_type, reply)
    })
  case response {
    types.Success(msg) -> Ok(msg)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn get_feed(
  client: Client,
  user_id: types.UserId,
  limit: Int,
) -> Result(List(types.Post), String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.GetFeed(user_id, limit, reply)
    })
  case response {
    types.PostListResponse(posts) -> Ok(posts)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn send_message(
  client: Client,
  from: types.UserId,
  to: types.UserId,
  content: String,
) -> Result(String, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.SendMessage(from, to, content, reply)
    })
  case response {
    types.Success(msg) -> Ok(msg)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn reply_to_message(
  client: Client,
  user_id: types.UserId,
  message_id: types.MessageId,
  content: String,
) -> Result(String, String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) {
      types.ReplyToMessage(user_id, message_id, content, reply)
    })
  case response {
    types.Success(msg) -> Ok(msg)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}

pub fn get_messages(
  client: Client,
  user_id: types.UserId,
) -> Result(List(types.DirectMessage), String) {
  let engine = get_engine(client)
  let response =
    process.call(engine, 5000, fn(reply) { types.GetMessages(user_id, reply) })
  case response {
    types.MessageListResponse(messages) -> Ok(messages)
    types.Error(msg) -> Error(msg)
    _ -> Error("Unexpected response type")
  }
}
