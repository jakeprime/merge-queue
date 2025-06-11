FROM ruby:alpine

LABEL "com.github.actions.name"="Merge queue"
LABEL "com.github.actions.description"="Safely enqueue and merge PRs after running CI against main"
LABEL "com.github.actions.icon"="git-merge"
LABEL "com.github.actions.color"="blue"

RUN gem install octokit

COPY merge_queue.rb /opt/merge_queue.rb

ENTRYPOINT ["ruby", "/opt/merge_queue.rb"]
