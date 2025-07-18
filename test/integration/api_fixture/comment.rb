# frozen_string_literal: true

module ApiFixture
  class Comment
    def to_s
      # From https://docs.github.com/en/rest/issues/comments#create-an-issue-comment
      <<~JSON
        {
          "id": 1,
          "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
          "url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
          "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
          "body": "Me too",
          "user": {
            "login": "octocat",
            "id": 1,
            "node_id": "MDQ6VXNlcjE=",
            "avatar_url": "https://github.com/images/error/octocat_happy.gif",
            "gravatar_id": "",
            "url": "https://api.github.com/users/octocat",
            "html_url": "https://github.com/octocat",
            "followers_url": "https://api.github.com/users/octocat/followers",
            "following_url": "https://api.github.com/users/octocat/following{/other_user}",
            "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}",
            "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}",
            "subscriptions_url": "https://api.github.com/users/octocat/subscriptions",
            "organizations_url": "https://api.github.com/users/octocat/orgs",
            "repos_url": "https://api.github.com/users/octocat/repos",
            "events_url": "https://api.github.com/users/octocat/events{/privacy}",
            "received_events_url": "https://api.github.com/users/octocat/received_events",
            "type": "User",
            "site_admin": false
          },
          "created_at": "2011-04-14T16:00:49Z",
          "updated_at": "2011-04-14T16:00:49Z",
          "issue_url": "https://api.github.com/repos/octocat/Hello-World/issues/1347",
          "author_association": "COLLABORATOR"
        }
      JSON
    end
  end
end
