import { BullModule } from '@nestjs/bullmq'
import { Module } from '@nestjs/common'

import { NotificationsProcessor } from './notifications.processor'

@Module({
  imports: [BullModule.registerQueue({ name: 'notifications' })],
  providers: [NotificationsProcessor],
})
export class NotificationsModule {}
