defmodule Ash.Test.Actions.BelongsToTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Ash.Test.Domain, as: Domain

  defmodule UpdateReviewFields do
    @moduledoc false
    use Ash.Resource.Change

    def init(_), do: {:ok, []}

    def change(changeset, _opts, _) do
      Ash.Changeset.before_action(changeset, fn changeset ->
        case Ash.Changeset.get_attribute(changeset, :requires_review) do
          true ->
            changeset

          false ->
            changeset
            |> Ash.Changeset.manage_relationship(:reviewer, nil, type: :append_and_remove)
            |> Ash.Changeset.force_change_attribute(:review_by_date, nil)
        end
      end)
    end
  end

  defmodule Post do
    @moduledoc false
    use Ash.Resource, domain: Domain, data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    actions do
      default_accept :*
      defaults([:read, :destroy, create: :*, update: :*])

      create :create_with_reviewer do
        argument :reviewer_id, :uuid, allow_nil?: true
        change manage_relationship(:reviewer_id, :reviewer, type: :append_and_remove)
      end

      update :update_with_reviewer do
        require_atomic? false
        argument :reviewer_id, :uuid, allow_nil?: true
        change manage_relationship(:reviewer_id, :reviewer, type: :append_and_remove)
        change {UpdateReviewFields, []}
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :title, :string, allow_nil?: false, public?: true
      attribute :requires_review, :boolean, allow_nil?: false, default: false, public?: true
      attribute :review_by_date, :date, allow_nil?: true, public?: true
    end

    relationships do
      belongs_to :reviewer, Ash.Test.Actions.BelongsToTest.Reviewer,
        allow_nil?: true,
        public?: true
    end
  end

  defmodule Reviewer do
    @moduledoc false
    use Ash.Resource, domain: Domain, data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    actions do
      default_accept :*
      defaults [:read, :destroy, create: :*, update: :*]
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, allow_nil?: false, public?: true
    end
  end

  test "change on update clears attribute and relationship" do
    reviewer =
      Reviewer
      |> Ash.Changeset.for_create(:create, %{name: "Zach"})
      |> Ash.create!()

    post =
      Post
      |> Ash.Changeset.for_create(:create_with_reviewer, %{
        title: "A Post",
        requires_review: true,
        reviewer_id: reviewer.id,
        review_by_date: DateTime.utc_now()
      })
      |> Ash.create!()
      |> Ash.load!(:reviewer)

    updated_post =
      post
      |> Ash.Changeset.for_update(:update_with_reviewer, %{
        requires_review: false
      })
      |> Ash.update!()
      |> Ash.load!(:reviewer)

    assert updated_post.requires_review == false
    assert updated_post.review_by_date == nil
    assert updated_post.reviewer == nil
  end
end
