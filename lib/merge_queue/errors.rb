# frozen_string_literal: true

module MergeQueue
  # Errors heirarchy:
  #
  #    MergeQueue::Error
  #                |
  #                |- CiErrorError
  #                |- CiFailedError
  #                |- FailedToCreateMergeBranchError
  #                |- GitCommandLineError
  #                |- MergeFailedError
  #                |- PrBranchUpdatedError
  #                |- PrMergeFailedError
  #                |- PrNotMergeableError
  #                |- PrNotRebaseableError
  #                |- RemoteUpdatedError
  #                |- UserCancelledError
  #                |
  #                |- RetriableError
  #                |  └- RemovedFromQueueError
  #                |
  #                └- TimeoutError
  #                   |- CiTimeoutError
  #                   |- CouldNotGetLockError
  #                   └- QueueTimeoutError

  Error = Class.new(StandardError)

  CiErrorError = Class.new(Error)
  CiFailedError = Class.new(Error)
  FailedToCreateMergeBranchError = Class.new(Error)
  GitCommandLineError = Class.new(Error)
  MergeFailedError = Class.new(Error)
  PrBranchUpdatedError = Class.new(Error)
  PrMergeFailedError = Class.new(Error)
  PrNotMergeableError = Class.new(Error)
  PrNotRebaseableError = Class.new(Error)
  RemoteUpdatedError = Class.new(Error)
  UserCancelledError = Class.new(Error)

  RetriableError = Class.new(Error)
  RemovedFromQueueError = Class.new(RetriableError)

  TimeoutError = Class.new(Error)
  CiTimeoutError = Class.new(TimeoutError)
  CouldNotGetLockError = Class.new(TimeoutError)
  QueueTimeoutError = Class.new(TimeoutError)
end
