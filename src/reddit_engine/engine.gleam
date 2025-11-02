import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/otp/actor
import gleam/string
import gleam/time/timestamp
import reddit_engine/types

pub type EngineState {
  EngineState(
    users: dict.Dict(String, types.User),
    subreddits: dict.Dict(String, types.Subreddit),
    posts: dict.Dict(String, types.Post),
    comments: dict.Dict(String, types.Comment),
    messages: dict.Dict(String, types.DirectMessage),
    user_ids: dict.Dict(String, types.UserId),
    next_user_id: Int,
    next_subreddit_id: Int,
    next_post_id: Int,
    next_comment_id: Int,
    next_message_id: Int,
  )
}

// Helper to get current system time in milliseconds
fn now_ms() -> Int {
  let ts = timestamp.system_time()
  let #(secs, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  let nanos_ms = case int.divide(nanos, 1_000_000) {
    Ok(v) -> v
    Error(_) -> 0
  }
  secs * 1000 + nanos_ms
}

pub fn start() -> process.Subject(types.EngineMessage) {
  let initial =
    EngineState(
      users: dict.new(),
      subreddits: dict.new(),
      posts: dict.new(),
      comments: dict.new(),
      messages: dict.new(),
      user_ids: dict.new(),
      next_user_id: 0,
      next_subreddit_id: 0,
      next_post_id: 0,
      next_comment_id: 0,
      next_message_id: 0,
    )

  let builder = actor.new(initial) |> actor.on_message(handle_message)
  case actor.start(builder) {
    Ok(actor.Started(_, subject)) -> subject
    Error(_) -> panic as "Failed to start engine actor"
  }
}

fn handle_message(
  state: EngineState,
  message: types.EngineMessage,
) -> actor.Next(EngineState, types.EngineMessage) {
  case message {
    types.RegisterUser(username, sender) ->
      handle_register_user(username, sender, state)
    types.GetUser(user_id, sender) -> handle_get_user(user_id, sender, state)
    types.CreateSubreddit(user_id, name, sender) ->
      handle_create_subreddit(user_id, name, sender, state)
    types.JoinSubreddit(user_id, subreddit_id, sender) ->
      handle_join_subreddit(user_id, subreddit_id, sender, state)
    types.LeaveSubreddit(user_id, subreddit_id, sender) ->
      handle_leave_subreddit(user_id, subreddit_id, sender, state)
    types.GetSubreddit(subreddit_id, sender) ->
      handle_get_subreddit(subreddit_id, sender, state)
    types.CreatePost(
      user_id,
      subreddit_id,
      title,
      content,
      original_post_id,
      sender,
    ) ->
      handle_create_post(
        user_id,
        subreddit_id,
        title,
        content,
        original_post_id,
        sender,
        state,
      )
    types.GetPost(post_id, sender) -> handle_get_post(post_id, sender, state)
    types.VotePost(user_id, post_id, vote_type, sender) ->
      handle_vote_post(user_id, post_id, vote_type, sender, state)
    types.CreateComment(user_id, post_id, parent_comment_id, content, sender) ->
      handle_create_comment(
        user_id,
        post_id,
        parent_comment_id,
        content,
        sender,
        state,
      )
    types.VoteComment(user_id, comment_id, vote_type, sender) ->
      handle_vote_comment(user_id, comment_id, vote_type, sender, state)
    types.GetFeed(user_id, limit, sender) ->
      handle_get_feed(user_id, limit, sender, state)
    types.SendMessage(from, to, content, sender) ->
      handle_send_message(from, to, content, sender, state)
    types.ReplyToMessage(user_id, message_id, reply_content, sender) ->
      handle_reply_message(user_id, message_id, reply_content, sender, state)
    types.GetMessages(user_id, sender) ->
      handle_get_messages(user_id, sender, state)
  }
}

// Helper handlers: follow the logic of engine_fixed.gleam but return actor.Next and
// pattern-match on Result from dict.get (Ok/Error) which matches the stdlib in this
// workspace. Replies are sent with process.send.

fn handle_register_user(
  username: String,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.user_ids, username) {
    Ok(_) -> {
      let _ = process.send(sender, types.Error("Username already exists"))
      actor.continue(state)
    }
    Error(_) -> {
      let user_id =
        types.UserId(string.append("user_", int.to_string(state.next_user_id)))
      let user =
        types.User(
          id: user_id,
          username: username,
          karma: 0,
          joined_subreddits: [],
        )
      let new_users =
        dict.insert(state.users, types.user_id_to_string(user_id), user)
      let new_user_ids = dict.insert(state.user_ids, username, user_id)
      let new_state =
        EngineState(
          users: new_users,
          subreddits: state.subreddits,
          posts: state.posts,
          comments: state.comments,
          messages: state.messages,
          user_ids: new_user_ids,
          next_user_id: state.next_user_id + 1,
          next_subreddit_id: state.next_subreddit_id,
          next_post_id: state.next_post_id,
          next_comment_id: state.next_comment_id,
          next_message_id: state.next_message_id,
        )
      let _ = process.send(sender, types.UserResponse(user))
      actor.continue(new_state)
    }
  }
}

fn handle_get_user(
  user_id: types.UserId,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.users, types.user_id_to_string(user_id)) {
    Ok(user) -> {
      let _ = process.send(sender, types.UserResponse(user))
      actor.continue(state)
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("User not found"))
      actor.continue(state)
    }
  }
}

fn handle_create_subreddit(
  user_id: types.UserId,
  name: String,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  let subreddit_id =
    types.SubredditId(string.append(
      "subreddit_",
      int.to_string(state.next_subreddit_id),
    ))
  let subreddit =
    types.Subreddit(
      id: subreddit_id,
      name: name,
      creator: user_id,
      members: [user_id],
      posts: [],
    )
  let new_subreddits =
    dict.insert(
      state.subreddits,
      types.subreddit_id_to_string(subreddit_id),
      subreddit,
    )

  case dict.get(state.users, types.user_id_to_string(user_id)) {
    Ok(user) -> {
      let updated_user =
        types.User(
          id: user.id,
          username: user.username,
          karma: user.karma,
          joined_subreddits: list.append(user.joined_subreddits, [subreddit_id]),
        )
      let new_users =
        dict.insert(state.users, types.user_id_to_string(user_id), updated_user)
      let new_state =
        EngineState(
          users: new_users,
          subreddits: new_subreddits,
          posts: state.posts,
          comments: state.comments,
          messages: state.messages,
          user_ids: state.user_ids,
          next_user_id: state.next_user_id,
          next_subreddit_id: state.next_subreddit_id + 1,
          next_post_id: state.next_post_id,
          next_comment_id: state.next_comment_id,
          next_message_id: state.next_message_id,
        )
      let _ = process.send(sender, types.SubredditResponse(subreddit))
      actor.continue(new_state)
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("User not found"))
      actor.continue(state)
    }
  }
}

fn handle_join_subreddit(
  user_id: types.UserId,
  subreddit_id: types.SubredditId,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.subreddits, types.subreddit_id_to_string(subreddit_id)) {
    Ok(subreddit) -> {
      case list.contains(subreddit.members, user_id) {
        True -> {
          let _ = process.send(sender, types.Error("Already a member"))
          actor.continue(state)
        }
        False -> {
          let updated_subreddit =
            types.Subreddit(
              id: subreddit.id,
              name: subreddit.name,
              creator: subreddit.creator,
              members: list.append(subreddit.members, [user_id]),
              posts: subreddit.posts,
            )
          let new_subreddits =
            dict.insert(
              state.subreddits,
              types.subreddit_id_to_string(subreddit_id),
              updated_subreddit,
            )

          case dict.get(state.users, types.user_id_to_string(user_id)) {
            Ok(user) -> {
              let updated_user =
                types.User(
                  id: user.id,
                  username: user.username,
                  karma: user.karma,
                  joined_subreddits: list.append(user.joined_subreddits, [
                    subreddit_id,
                  ]),
                )
              let new_users =
                dict.insert(
                  state.users,
                  types.user_id_to_string(user_id),
                  updated_user,
                )
              let new_state =
                EngineState(
                  users: new_users,
                  subreddits: new_subreddits,
                  posts: state.posts,
                  comments: state.comments,
                  messages: state.messages,
                  user_ids: state.user_ids,
                  next_user_id: state.next_user_id,
                  next_subreddit_id: state.next_subreddit_id,
                  next_post_id: state.next_post_id,
                  next_comment_id: state.next_comment_id,
                  next_message_id: state.next_message_id,
                )
              let _ = process.send(sender, types.Success("Joined subreddit"))
              actor.continue(new_state)
            }
            Error(_) -> {
              let _ = process.send(sender, types.Error("User not found"))
              actor.continue(state)
            }
          }
        }
      }
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("Subreddit not found"))
      actor.continue(state)
    }
  }
}

fn handle_leave_subreddit(
  user_id: types.UserId,
  subreddit_id: types.SubredditId,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.subreddits, types.subreddit_id_to_string(subreddit_id)) {
    Ok(subreddit) -> {
      let updated_members =
        list.filter(subreddit.members, fn(id) { id != user_id })
      let updated_subreddit =
        types.Subreddit(
          id: subreddit.id,
          name: subreddit.name,
          creator: subreddit.creator,
          members: updated_members,
          posts: subreddit.posts,
        )
      let new_subreddits =
        dict.insert(
          state.subreddits,
          types.subreddit_id_to_string(subreddit_id),
          updated_subreddit,
        )

      case dict.get(state.users, types.user_id_to_string(user_id)) {
        Ok(user) -> {
          let updated_user =
            types.User(
              id: user.id,
              username: user.username,
              karma: user.karma,
              joined_subreddits: list.filter(user.joined_subreddits, fn(id) {
                id != subreddit_id
              }),
            )
          let new_users =
            dict.insert(
              state.users,
              types.user_id_to_string(user_id),
              updated_user,
            )
          let new_state =
            EngineState(
              users: new_users,
              subreddits: new_subreddits,
              posts: state.posts,
              comments: state.comments,
              messages: state.messages,
              user_ids: state.user_ids,
              next_user_id: state.next_user_id,
              next_subreddit_id: state.next_subreddit_id,
              next_post_id: state.next_post_id,
              next_comment_id: state.next_comment_id,
              next_message_id: state.next_message_id,
            )
          let _ = process.send(sender, types.Success("Left subreddit"))
          actor.continue(new_state)
        }
        Error(_) -> {
          let _ = process.send(sender, types.Error("User not found"))
          actor.continue(state)
        }
      }
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("Subreddit not found"))
      actor.continue(state)
    }
  }
}

fn handle_get_subreddit(
  subreddit_id: types.SubredditId,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.subreddits, types.subreddit_id_to_string(subreddit_id)) {
    Ok(subreddit) -> {
      let _ = process.send(sender, types.SubredditResponse(subreddit))
      actor.continue(state)
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("Subreddit not found"))
      actor.continue(state)
    }
  }
}

fn handle_create_post(
  user_id: types.UserId,
  subreddit_id: types.SubredditId,
  title: String,
  content: String,
  original_post_id: option.Option(types.PostId),
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.subreddits, types.subreddit_id_to_string(subreddit_id)) {
    Ok(subreddit) -> {
      case list.contains(subreddit.members, user_id) {
        True -> {
          let post_id =
            types.PostId(string.append(
              "post_",
              int.to_string(state.next_post_id),
            ))
          let is_repost = option.is_some(original_post_id)
          let post =
            types.Post(
              id: post_id,
              subreddit_id: subreddit_id,
              author: user_id,
              title: title,
              content: content,
              upvotes: 0,
              downvotes: 0,
              comments: [],
              created_at: now_ms(),
              is_repost: is_repost,
              original_post_id: original_post_id,
            )
          let new_posts =
            dict.insert(state.posts, types.post_id_to_string(post_id), post)

          let updated_subreddit =
            types.Subreddit(
              id: subreddit.id,
              name: subreddit.name,
              creator: subreddit.creator,
              members: subreddit.members,
              posts: list.append(subreddit.posts, [post_id]),
            )
          let new_subreddits =
            dict.insert(
              state.subreddits,
              types.subreddit_id_to_string(subreddit_id),
              updated_subreddit,
            )

          let new_state =
            EngineState(
              users: state.users,
              subreddits: new_subreddits,
              posts: new_posts,
              comments: state.comments,
              messages: state.messages,
              user_ids: state.user_ids,
              next_user_id: state.next_user_id,
              next_subreddit_id: state.next_subreddit_id,
              next_post_id: state.next_post_id + 1,
              next_comment_id: state.next_comment_id,
              next_message_id: state.next_message_id,
            )
          let _ = process.send(sender, types.PostResponse(post))
          actor.continue(new_state)
        }
        False -> {
          let _ =
            process.send(
              sender,
              types.Error("User is not a member of this subreddit"),
            )
          actor.continue(state)
        }
      }
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("Subreddit not found"))
      actor.continue(state)
    }
  }
}

fn handle_get_post(
  post_id: types.PostId,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.posts, types.post_id_to_string(post_id)) {
    Ok(post) -> {
      let _ = process.send(sender, types.PostResponse(post))
      actor.continue(state)
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("Post not found"))
      actor.continue(state)
    }
  }
}

fn handle_vote_post(
  _user_id: types.UserId,
  post_id: types.PostId,
  vote_type: types.VoteType,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.posts, types.post_id_to_string(post_id)) {
    Ok(post) -> {
      let updated_post = case vote_type {
        types.Upvote -> types.Post(..post, upvotes: post.upvotes + 1)
        types.Downvote -> types.Post(..post, downvotes: post.downvotes + 1)
      }
      let new_posts =
        dict.insert(state.posts, types.post_id_to_string(post_id), updated_post)

      case dict.get(state.users, types.user_id_to_string(post.author)) {
        Ok(user) -> {
          let karma_delta = case vote_type {
            types.Upvote -> 1
            types.Downvote -> -1
          }
          let updated_user = types.User(..user, karma: user.karma + karma_delta)
          let new_users =
            dict.insert(
              state.users,
              types.user_id_to_string(post.author),
              updated_user,
            )
          let new_state =
            EngineState(
              users: new_users,
              subreddits: state.subreddits,
              posts: new_posts,
              comments: state.comments,
              messages: state.messages,
              user_ids: state.user_ids,
              next_user_id: state.next_user_id,
              next_subreddit_id: state.next_subreddit_id,
              next_post_id: state.next_post_id,
              next_comment_id: state.next_comment_id,
              next_message_id: state.next_message_id,
            )
          let _ = process.send(sender, types.Success("Voted"))
          actor.continue(new_state)
        }
        Error(_) -> {
          let _ = process.send(sender, types.Error("Post author not found"))
          actor.continue(state)
        }
      }
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("Post not found"))
      actor.continue(state)
    }
  }
}

fn handle_create_comment(
  user_id: types.UserId,
  post_id: types.PostId,
  parent_comment_id: option.Option(types.CommentId),
  content: String,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.posts, types.post_id_to_string(post_id)) {
    Ok(post) -> {
      let comment_id =
        types.CommentId(string.append(
          "comment_",
          int.to_string(state.next_comment_id),
        ))
      let comment =
        types.Comment(
          id: comment_id,
          post_id: post_id,
          parent_comment_id: parent_comment_id,
          author: user_id,
          content: content,
          upvotes: 0,
          downvotes: 0,
          replies: [],
          created_at: now_ms(),
        )
      let new_comments =
        dict.insert(
          state.comments,
          types.comment_id_to_string(comment_id),
          comment,
        )

      let updated_post =
        types.Post(..post, comments: list.append(post.comments, [comment_id]))
      let new_posts =
        dict.insert(state.posts, types.post_id_to_string(post_id), updated_post)

      let final_comments = case parent_comment_id {
        option.Some(parent_id) -> {
          case dict.get(new_comments, types.comment_id_to_string(parent_id)) {
            Ok(parent_comment) -> {
              let updated_parent =
                types.Comment(
                  ..parent_comment,
                  replies: list.append(parent_comment.replies, [comment_id]),
                )
              dict.insert(
                new_comments,
                types.comment_id_to_string(parent_id),
                updated_parent,
              )
            }
            Error(_) -> new_comments
          }
        }
        option.None -> new_comments
      }

      let new_state =
        EngineState(
          users: state.users,
          subreddits: state.subreddits,
          posts: new_posts,
          comments: final_comments,
          messages: state.messages,
          user_ids: state.user_ids,
          next_user_id: state.next_user_id,
          next_subreddit_id: state.next_subreddit_id,
          next_post_id: state.next_post_id,
          next_comment_id: state.next_comment_id + 1,
          next_message_id: state.next_message_id,
        )
      let _ = process.send(sender, types.CommentResponse(comment))
      actor.continue(new_state)
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("Post not found"))
      actor.continue(state)
    }
  }
}

fn handle_vote_comment(
  _user_id: types.UserId,
  comment_id: types.CommentId,
  vote_type: types.VoteType,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.comments, types.comment_id_to_string(comment_id)) {
    Ok(comment) -> {
      let updated_comment = case vote_type {
        types.Upvote -> types.Comment(..comment, upvotes: comment.upvotes + 1)
        types.Downvote ->
          types.Comment(..comment, downvotes: comment.downvotes + 1)
      }
      let new_comments =
        dict.insert(
          state.comments,
          types.comment_id_to_string(comment_id),
          updated_comment,
        )

      case dict.get(state.users, types.user_id_to_string(comment.author)) {
        Ok(user) -> {
          let karma_delta = case vote_type {
            types.Upvote -> 1
            types.Downvote -> -1
          }
          let updated_user = types.User(..user, karma: user.karma + karma_delta)
          let new_users =
            dict.insert(
              state.users,
              types.user_id_to_string(comment.author),
              updated_user,
            )
          let new_state =
            EngineState(
              users: new_users,
              subreddits: state.subreddits,
              posts: state.posts,
              comments: new_comments,
              messages: state.messages,
              user_ids: state.user_ids,
              next_user_id: state.next_user_id,
              next_subreddit_id: state.next_subreddit_id,
              next_post_id: state.next_post_id,
              next_comment_id: state.next_comment_id,
              next_message_id: state.next_message_id,
            )
          let _ = process.send(sender, types.Success("Voted"))
          actor.continue(new_state)
        }
        Error(_) -> {
          let _ = process.send(sender, types.Error("Comment author not found"))
          actor.continue(state)
        }
      }
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("Comment not found"))
      actor.continue(state)
    }
  }
}

fn handle_get_feed(
  user_id: types.UserId,
  limit: Int,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.users, types.user_id_to_string(user_id)) {
    Ok(user) -> {
      let feed_posts =
        list.fold(user.joined_subreddits, [], fn(acc, subreddit_id) {
          case
            dict.get(
              state.subreddits,
              types.subreddit_id_to_string(subreddit_id),
            )
          {
            Ok(subreddit) -> {
              list.fold(subreddit.posts, acc, fn(acc2, post_id) {
                case dict.get(state.posts, types.post_id_to_string(post_id)) {
                  Ok(post) -> list.append(acc2, [post])
                  Error(_) -> acc2
                }
              })
            }
            Error(_) -> acc
          }
        })
        |> list.sort(fn(a, b) {
          case a.created_at > b.created_at {
            True -> order.Gt
            False -> order.Lt
          }
        })
        |> list.take(limit)

      let _ = process.send(sender, types.PostListResponse(feed_posts))
      actor.continue(state)
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("User not found"))
      actor.continue(state)
    }
  }
}

fn handle_send_message(
  from: types.UserId,
  to: types.UserId,
  content: String,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  let message_id =
    types.MessageId(string.append(
      "message_",
      int.to_string(state.next_message_id),
    ))
  let message =
    types.DirectMessage(
      id: message_id,
      from: from,
      to: to,
      content: content,
      replies: [],
      parent_message_id: option.None,
      created_at: now_ms(),
    )
  let new_messages =
    dict.insert(state.messages, types.message_id_to_string(message_id), message)
  let new_state =
    EngineState(
      users: state.users,
      subreddits: state.subreddits,
      posts: state.posts,
      comments: state.comments,
      messages: new_messages,
      user_ids: state.user_ids,
      next_user_id: state.next_user_id,
      next_subreddit_id: state.next_subreddit_id,
      next_post_id: state.next_post_id,
      next_comment_id: state.next_comment_id,
      next_message_id: state.next_message_id + 1,
    )
  let _ = process.send(sender, types.Success("Message sent"))
  actor.continue(new_state)
}

fn handle_reply_message(
  user_id: types.UserId,
  message_id: types.MessageId,
  reply_content: String,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  case dict.get(state.messages, types.message_id_to_string(message_id)) {
    Ok(parent_message) -> {
      let reply_id =
        types.MessageId(string.append(
          "message_",
          int.to_string(state.next_message_id),
        ))
      let reply =
        types.DirectMessage(
          id: reply_id,
          from: user_id,
          to: parent_message.from,
          content: reply_content,
          replies: [],
          parent_message_id: option.Some(message_id),
          created_at: now_ms(),
        )
      let new_messages =
        dict.insert(state.messages, types.message_id_to_string(reply_id), reply)

      let updated_parent =
        types.DirectMessage(
          ..parent_message,
          replies: list.append(parent_message.replies, [reply_id]),
        )
      let final_messages =
        dict.insert(
          new_messages,
          types.message_id_to_string(message_id),
          updated_parent,
        )

      let new_state =
        EngineState(
          users: state.users,
          subreddits: state.subreddits,
          posts: state.posts,
          comments: state.comments,
          messages: final_messages,
          user_ids: state.user_ids,
          next_user_id: state.next_user_id,
          next_subreddit_id: state.next_subreddit_id,
          next_post_id: state.next_post_id,
          next_comment_id: state.next_comment_id,
          next_message_id: state.next_message_id + 1,
        )
      let _ = process.send(sender, types.Success("Replied to message"))
      actor.continue(new_state)
    }
    Error(_) -> {
      let _ = process.send(sender, types.Error("Message not found"))
      actor.continue(state)
    }
  }
}

fn handle_get_messages(
  user_id: types.UserId,
  sender: process.Subject(types.EngineResponse),
  state: EngineState,
) -> actor.Next(EngineState, types.EngineMessage) {
  let user_messages =
    list.filter(dict.values(state.messages), fn(msg) { msg.to == user_id })
  let _ = process.send(sender, types.MessageListResponse(user_messages))
  actor.continue(state)
}
