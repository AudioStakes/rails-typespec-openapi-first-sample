module Api
  class TasksController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "Task not found" }, status: :not_found
    end

    def index
      tasks = Task.order(:id)
      status = request.query_parameters["status"]
      tasks = tasks.where(status: status) if status
      render json: tasks.map { |task| task_json(task) }
    end

    def create
      task = Task.create!(request.request_parameters.slice("title").merge("status" => "todo"))
      render json: task_json(task), status: :created
    end

    def show
      render json: task_json(Task.find(params[:id]))
    end

    def update
      task = Task.find(params[:id])
      task.update!(request.request_parameters.slice("title", "status"))
      render json: task_json(task)
    end

    private

    def task_json(task)
      task.attributes.slice("id", "title", "status")
    end
  end
end
