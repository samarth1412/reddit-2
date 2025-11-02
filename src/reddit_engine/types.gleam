import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}

pub type UserId {
  UserId(String)
}

pub type SubredditId {
  SubredditId(String)
}

pub type PostId {
  PostId(String)
}

pub type CommentId {
  CommentId(String)
}

pub type MessageId {
  MessageId(String)
}

pub type User {
  User(
    id: UserId,
    username: String,
    karma: Int,
    joined_subreddits: List(SubredditId),
  )
}

pub type Subreddit {
  Subreddit(
    id: SubredditId,
    name: String,
    creator: UserId,
    members: List(UserId),
    posts: List(PostId),
  )
}

pub type Post {
  Post(
    id: PostId,
    subreddit_id: SubredditId,
    author: UserId,
    title: String,
    content: String,
    upvotes: Int,
    downvotes: Int,
    comments: List(CommentId),
    created_at: Int,
    // timestamp
    is_repost: Bool,
    original_post_id: Option(PostId),
  )
}

pub type Comment {
  Comment(
    id: CommentId,
    post_id: PostId,
    parent_comment_id: Option(CommentId),
    // None for top-level comments
    author: UserId,
    content: String,
    upvotes: Int,
    downvotes: Int,
    replies: List(CommentId),
    created_at: Int,
  )
}

pub type DirectMessage {
  DirectMessage(
    id: MessageId,
    from: UserId,
    to: UserId,
    content: String,
    replies: List(MessageId),
    parent_message_id: Option(MessageId),
    // None for original messages, Some(id) for replies
    created_at: Int,
  )
}

pub type EngineMessage {
  RegisterUser(String, Subject(EngineResponse))
  GetUser(UserId, Subject(EngineResponse))
  CreateSubreddit(UserId, String, Subject(EngineResponse))
  JoinSubreddit(UserId, SubredditId, Subject(EngineResponse))
  LeaveSubreddit(UserId, SubredditId, Subject(EngineResponse))
  GetSubreddit(SubredditId, Subject(EngineResponse))
  CreatePost(
    UserId,
    SubredditId,
    String,
    String,
    Option(PostId),
    Subject(EngineResponse),
  )
  GetPost(PostId, Subject(EngineResponse))
  VotePost(UserId, PostId, VoteType, Subject(EngineResponse))
  CreateComment(
    UserId,
    PostId,
    Option(CommentId),
    String,
    Subject(EngineResponse),
  )
  VoteComment(UserId, CommentId, VoteType, Subject(EngineResponse))
  GetFeed(UserId, Int, Subject(EngineResponse))
  SendMessage(UserId, UserId, String, Subject(EngineResponse))
  ReplyToMessage(UserId, MessageId, String, Subject(EngineResponse))
  GetMessages(UserId, Subject(EngineResponse))
}

pub type VoteType {
  Upvote
  Downvote
}

pub type EngineResponse {
  Success(String)
  Error(String)
  UserResponse(User)
  SubredditResponse(Subreddit)
  PostResponse(Post)
  CommentResponse(Comment)
  PostListResponse(List(Post))
  MessageListResponse(List(DirectMessage))
}

pub fn user_id_to_string(id: UserId) -> String {
  case id {
    UserId(s) -> s
  }
}

pub fn subreddit_id_to_string(id: SubredditId) -> String {
  case id {
    SubredditId(s) -> s
  }
}

pub fn post_id_to_string(id: PostId) -> String {
  case id {
    PostId(s) -> s
  }
}

pub fn comment_id_to_string(id: CommentId) -> String {
  case id {
    CommentId(s) -> s
  }
}

pub fn message_id_to_string(id: MessageId) -> String {
  case id {
    MessageId(s) -> s
  }
}
