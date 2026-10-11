module Api
  class TasksController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "Task not found" }, status: :not_found
    end

    def index
      tasks = Task.order(:id)
      status = openapi_request.parsed_query["status"]
      tasks = tasks.where(status: status) if status
      render json: tasks.map { |task| task_json(task) }
    end

    def create
      task = Task.create!(openapi_request.parsed_body.slice("title").merge("status" => "todo"))
      render json: task_json(task), status: :created
    end

    def show
      render json: task_json(Task.find(openapi_request.parsed_path_parameters.fetch("id")))
    end

    def update
      task = Task.find(openapi_request.parsed_path_parameters.fetch("id"))
      task.update!(openapi_request.parsed_body.slice("title", "status"))
      render json: task_json(task)
    end

    private

    def openapi_request
      request.env.fetch(OpenapiFirst::REQUEST)
    end

    def task_json(task)
      task.attributes.slice("id", "title", "status")
    end
  end
end
