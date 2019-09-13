alias Arc.Storage.GCS
alias GoogleApi.Storage.V1.Api.Objects

defmodule Cleanup do
  def execute(_) do
    conn = GCS.conn()
    bucket = GCS.bucket(DummyDefinition)
    cleanup_bucket(conn, bucket)
  end

  def cleanup_bucket(conn, bucket) do
    delete_from_bucket(conn, bucket, [], nil)
  end

  def delete_from_bucket(conn, bucket, errors, page) do
    case Objects.storage_objects_list(conn, bucket, pageToken: page) do
      {:ok, objects} -> delete_objects(conn, bucket, errors, objects)
      {:error, error} -> [error | errors]
    end
  end

  def delete_objects(_conn, _bucket, errors, %{items: []}), do: errors
  def delete_objects(conn, bucket, errors, %{items: items, nextPageToken: next}) do
    errors = Enum.reduce(items, errors, fn %{name: name}, errs ->
      case Objects.storage_objects_delete(conn, bucket, name) do
        {:ok, _} -> errs
        {:error, err} -> [err | errs]
      end
    end)

    case next do
      nil -> errors
      _ -> delete_from_bucket(conn, bucket, errors, next)
    end
  end
end
