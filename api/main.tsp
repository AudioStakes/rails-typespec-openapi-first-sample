import "@typespec/http";
import "@typespec/openapi";

using TypeSpec.Http;
using TypeSpec.OpenAPI;

@service(#{ title: "Tasks API" })
@info(#{ version: "1.0.0" })
@server("http://localhost:3000", "Local Rails server")
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

// Boolean false preserves sealing and lets Redoc display closed objects correctly.
@extension("unevaluatedProperties", false)
model Task {
  id: int64;
  title: TaskTitle;
  status: TaskStatus;
}

@extension("unevaluatedProperties", false)
model CreateTask {
  title: TaskTitle;
}

/** An empty object is a valid update; null values are not allowed. */
@extension("unevaluatedProperties", false)
model UpdateTask {
  title?: TaskTitle;
  status?: TaskStatus;
}

@extension("unevaluatedProperties", false)
model NotFoundError {
  error: string;
}

/** The default error response returned by openapi_first. */
@extension("unevaluatedProperties", false)
model Problem<Code extends int32> {
  title: string;
  status: Code;
  errors?: ValidationError[];
}

@extension("unevaluatedProperties", false)
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
  @get
  list(@query status?: TaskStatus): Task[] | BadRequest;

  /** Create a task with status=todo. */
  @post
  create(@body task: CreateTask): {
    @statusCode statusCode: 201;
    @body body: Task;
  } | BadRequest | UnsupportedMediaType;

  @get
  @route("/{id}")
  read(@path id: int64): Task | BadRequest | NotFound;

  @patch
  @route("/{id}")
  update(@path id: int64, @body task: UpdateTask):
    Task | BadRequest | UnsupportedMediaType | NotFound;
}
