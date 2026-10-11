require "rails_helper"

RSpec.describe "Tasks API", type: :request do
  def stored_tasks
    Task.order(:id).pluck(:id, :title, :status)
  end

  def expect_problem(status)
    expect(response).to have_http_status(status)
    expect(response.media_type).to eq("application/problem+json")
    expect(response.parsed_body).to include("status" => status, "title" => a_kind_of(String))
    OpenapiContract.validate_unsupported_media_type_response(request, response) if status == 415
  end

  describe "POST /api/tasks" do
    it "saves a task with the default status and returns it" do
      expect { post "/api/tasks", params: { title: "Review the API" }, as: :json }
        .to change(Task, :count).by(1)

      task = Task.last
      expect(task.attributes).to include("title" => "Review the API", "status" => "todo")
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("id" => task.id, "title" => task.title, "status" => "todo")
    end

    it "preserves whitespace without trimming a nonempty title" do
      post "/api/tasks", params: { title: "   " }, as: :json

      expect(response).to have_http_status(:created)
      expect(Task.last.title).to eq("   ")
      expect(response.parsed_body).to include("title" => "   ")
    end

    it "accepts a title of 100 Unicode characters" do
      title = "あ" * 100
      post "/api/tasks", params: { title: title }, as: :json

      expect(response).to have_http_status(:created)
      expect(Task.last.title).to eq(title)
      expect(response.parsed_body).to include("title" => title)
    end

    it "counts an embedded null character as one character" do
      post "/api/tasks", params: { title: "\u0000" }, as: :json

      expect(response).to have_http_status(:created)
      expect(Task.last.title).to eq("\u0000")
      expect(response.parsed_body).to include("title" => "\u0000")
    end

    {
      "missing title" => {},
      "empty title" => { title: "" },
      "title of 101 Unicode characters" => { title: "あ" * 101 },
      "numeric title" => { title: 123 },
      "null title" => { title: nil },
      "unknown property" => { title: "Task", extra: true },
      "client supplied status" => { title: "Task", status: "done" }
    }.each do |description, body|
      it "rejects #{description} without saving",
         invalid_request: { method: "POST", path: "/api/tasks", error: :invalid_body } do
        expect { post "/api/tasks", params: body, as: :json }.not_to change { stored_tasks }

        expect_problem(400)
      end
    end

    it "rejects malformed JSON without saving",
       invalid_request: { method: "POST", path: "/api/tasks", error: :invalid_body } do
      expect do
        post "/api/tasks", params: '{"title":', headers: { "CONTENT_TYPE" => "application/json" }
      end.not_to change { stored_tasks }

      expect_problem(400)
    end

    it "rejects an unsupported Content-Type without saving",
       invalid_request: { method: "POST", path: "/api/tasks", error: :unsupported_media_type } do
      expect do
        post "/api/tasks", params: { title: "Task" }.to_json, headers: { "CONTENT_TYPE" => "text/plain" }
      end.not_to change { stored_tasks }

      expect_problem(415)
    end
  end

  describe "GET /api/tasks" do
    it "returns saved tasks in ascending id order" do
      second = Task.create!(id: 20, title: "Second", status: "doing")
      first = Task.create!(id: 10, title: "First", status: "todo")

      get "/api/tasks"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |task| task.fetch("id") }).to eq([ first.id, second.id ])
      expect(response.parsed_body).to include(
        a_hash_including("id" => first.id, "title" => "First", "status" => "todo"),
        a_hash_including("id" => second.id, "title" => "Second", "status" => "doing")
      )
    end

    it "filters by status" do
      Task.create!(title: "Todo", status: "todo")
      Task.create!(title: "Doing", status: "doing")
      done = Task.create!(title: "Done", status: "done")

      get "/api/tasks", params: { status: "done" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |task| task.fetch("id") }).to eq([ done.id ])
    end

    it "uses the query rather than the body to filter a GET" do
      todo = Task.create!(title: "Todo", status: "todo")
      done = Task.create!(title: "Done", status: "done")

      body = '{"status":"done"}'
      get "/api/tasks", env: {
        "rack.input" => StringIO.new(body),
        "CONTENT_TYPE" => "application/json",
        "CONTENT_LENGTH" => body.bytesize.to_s
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |task| task.fetch("id") }).to eq([ todo.id, done.id ])
    end

    it "ignores query values that the runtime contract has not parsed" do
      todo = Task.create!(title: "Todo", status: "todo")
      done = Task.create!(title: "Done", status: "done")

      # The runtime permits unknown query keys; exempt this request from Test.setup's stricter check.
      test_configuration = OpenapiFirst::Test.configuration
      allow(test_configuration).to receive(:raise_request_error?).and_call_original
      allow(test_configuration).to receive(:raise_request_error?).with(have_attributes(
        request_method: "GET", path: "/api/tasks", known?: true, valid?: true,
        unknown_query_parameters: { "status[extra]" => "done" }
      )).and_return(false)

      expect { get "/api/tasks?status%5Bextra%5D=done" }.not_to change { stored_tasks }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |task| task.fetch("id") }).to eq([ todo.id, done.id ])
    end

    it "rejects an unknown status without changing tasks",
       invalid_request: { method: "GET", path: "/api/tasks", error: :invalid_query } do
      Task.create!(title: "Existing", status: "todo")

      expect { get "/api/tasks", params: { status: "paused" } }.not_to change { stored_tasks }

      expect_problem(400)
    end

    it "rejects a numeric status query value",
       invalid_request: { method: "GET", path: "/api/tasks", error: :invalid_query } do
      expect { get "/api/tasks", params: { status: 123 } }.not_to change { stored_tasks }

      expect_problem(400)
    end
  end

  describe "GET /api/tasks/{id}" do
    it "returns the requested task" do
      Task.create!(title: "Another", status: "todo")
      task = Task.create!(title: "Requested", status: "doing")

      get "/api/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => task.id, "title" => task.title, "status" => task.status)
    end

    it "returns 404 for a missing task" do
      get "/api/tasks/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to include("error" => "Task not found")
    end

    it "rejects a noninteger path id",
       invalid_request: { method: "GET", path: "/api/tasks/abc", error: :invalid_path } do
      expect { get "/api/tasks/abc" }.not_to change { stored_tasks }

      expect_problem(400)
    end
  end

  describe "PATCH /api/tasks/{id}" do
    let!(:task) { Task.create!(id: 42, title: "Original", status: "doing") }
    let(:path) { "/api/tasks/#{task.id}" }

    it "updates only title when status is omitted" do
      patch path, params: { title: "Updated" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(task.reload.attributes).to include("title" => "Updated", "status" => "doing")
      expect(response.parsed_body).to include("id" => task.id, "title" => "Updated", "status" => "doing")
    end

    it "updates only status when title is omitted" do
      patch path, params: { status: "done" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(task.reload.attributes).to include("title" => "Original", "status" => "done")
      expect(response.parsed_body).to include("id" => task.id, "title" => "Original", "status" => "done")
    end

    it "treats an empty object as a successful no-op" do
      expect { patch path, params: {}, as: :json }.not_to change { stored_tasks }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => task.id, "title" => "Original", "status" => "doing")
    end

    {
      "empty title" => { title: "" },
      "null title" => { title: nil },
      "unknown status" => { title: "Would change", status: "paused" },
      "null status" => { title: "Would change", status: nil },
      "unknown property" => { title: "Would change", extra: true }
    }.each do |description, body|
      it "rejects #{description} without updating",
         invalid_request: { method: "PATCH", path: "/api/tasks/42", error: :invalid_body } do
        expect { patch path, params: body, as: :json }.not_to change { stored_tasks }

        expect_problem(400)
      end
    end

    it "returns 404 for a missing task without updating another task" do
      expect do
        patch "/api/tasks/999999", params: { title: "Updated" }, as: :json
      end.not_to change { stored_tasks }

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to include("error" => "Task not found")
    end

    it "rejects an unsupported Content-Type without updating",
       invalid_request: { method: "PATCH", path: "/api/tasks/42", error: :unsupported_media_type } do
      expect do
        patch path, params: { title: "Updated" }.to_json, headers: { "CONTENT_TYPE" => "text/plain" }
      end.not_to change { stored_tasks }

      expect_problem(415)
    end

    it "rejects a noninteger path id without updating",
       invalid_request: { method: "PATCH", path: "/api/tasks/abc", error: :invalid_path } do
      expect do
        patch "/api/tasks/abc", params: { title: "Updated" }, as: :json
      end.not_to change { stored_tasks }

      expect_problem(400)
    end
  end
end
