import { Processor, WorkerHost } from '@nestjs/bullmq'
import { Logger } from '@nestjs/common'
import { Job } from 'bullmq'

type NotificationJob = {
  userId: string
  title: string
  body: string
}

@Processor('notifications')
export class NotificationsProcessor extends WorkerHost {
  private readonly logger = new Logger(NotificationsProcessor.name)

  async process(job: Job<NotificationJob>) {
    this.logger.log(`Processing notification job ${job.id} for user ${job.data.userId}`)

    return {
      delivered: true,
      jobId: job.id,
    }
  }
}
