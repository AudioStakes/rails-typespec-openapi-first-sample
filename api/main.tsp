import "@typespec/http";
import "@typespec/openapi";

using TypeSpec.Http;
using TypeSpec.OpenAPI;

@service(#{ title: "Tasks API" })
@info(#{ version: "1.0.0" })
@server("/", "Same-origin Rails API")
namespace TasksApi;

/** Shared by the response and both request models. */
@minLength(1)
@maxLength(100)
scalar TaskTitle extends string;

enum TaskStatus {
  todo,
  doing,
  done,
}

model Task {
  id: int64;
  title: TaskTitle;
  status: TaskStatus;
}

model CreateTask {
  title: TaskTitle;
}

/** An empty object is a valid update; null values are not allowed. */
model UpdateTask {
  title?: TaskTitle;
  status?: TaskStatus;
}

model NotFoundError {
  error: string;
}

/** The default error response returned by openapi_first. */
model Problem<Code extends int32> {
  title: string;
  status: Code;
  errors?: ValidationError[];
}

model ValidationError {
  message: string;
  code: string;
  pointer?: string;
  parameter?: string;
  header?: string;
  cookie?: string;
}

@error
model BadRequest {
  @statusCode statusCode: 400;
  @header contentType: "application/problem+json";
  @body body: Problem<400>;
}

@error
model UnsupportedMediaType {
  @statusCode statusCode: 415;
  @header contentType: "application/problem+json";
  @body body: Problem<415>;
}

@error
model NotFound {
  @statusCode statusCode: 404;
  @body body: NotFoundError;
}

@route("/api/tasks")
interface Tasks {
  /** Return tasks in ascending id order, optionally filtered by status. */
  @summary("タスク一覧を取得する")
  @get
  list(@query status?: TaskStatus): Task[] | BadRequest;

  /** Create a task with status=todo. */
  @summary("タスクを作成する")
  @post
  create(@body task: CreateTask): {
    @statusCode statusCode: 201;
    @body body: Task;
  } | BadRequest | UnsupportedMediaType;

  @summary("タスクを取得する")
  @get
  @route("/{id}")
  read(@path id: int64): Task | BadRequest | NotFound;

  @summary("タスクを更新する")
  @patch
  @route("/{id}")
  update(@path id: int64, @body task: UpdateTask):
    Task | BadRequest | UnsupportedMediaType | NotFound;
}
