# frozen_string_literal: true

module MergeQueue
  # Errors heirarchy:
  #
  #    MergeQueue::Error
  #                |
  #                |- CiFailedError
  #                |- GitCommandLineError
  #                |- MergeFailedError
  #                |- PrBranchUpdatedError
  #                |- PrMergeFailedError
  #                |- PrNotMergeableError
  #                |- PrNotRebaseableError
  #                |- RemoteUpdatedError
  #                |
  #                |- RetriableError
  #                |  └- RemovedFromQueueError
  #                |
  #                └- TimeoutError
  #                   |- CiTimeoutError
  #                   |- CouldNotGetLockError
  #                   └- QueueTimeoutError

  Error = Class.new(StandardError)

  CiFailedError = Class.new(Error)
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
