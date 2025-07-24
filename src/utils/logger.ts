import winston from 'winston';
import path from 'path';

export class Logger {
  private static instance: winston.Logger;

  static getInstance(): winston.Logger {
    if (!Logger.instance) {
      Logger.instance = winston.createLogger({
        level: 'info',
        format: winston.format.combine(
          winston.format.timestamp(),
          winston.format.errors({ stack: true }),
          winston.format.json()
        ),
        defaultMeta: { service: 'bulk-copilot-config' },
        transports: [
          new winston.transports.File({
            filename: 'operations.log',
            level: 'info'
          }),
          new winston.transports.Console({
            format: winston.format.combine(
              winston.format.colorize(),
              winston.format.simple()
            )
          })
        ]
      });
    }
    return Logger.instance;
  }

  static setLevel(level: string) {
    Logger.getInstance().level = level;
  }

  static info(message: string, meta?: any) {
    Logger.getInstance().info(message, meta);
  }

  static error(message: string, meta?: any) {
    Logger.getInstance().error(message, meta);
  }

  static warn(message: string, meta?: any) {
    Logger.getInstance().warn(message, meta);
  }

  static debug(message: string, meta?: any) {
    Logger.getInstance().debug(message, meta);
  }
}