"""WiggleAI — Logger config using Loguru"""
import sys
from loguru import logger
from core.config import settings

logger.remove()
logger.add(
    sys.stdout,
    colorize=True,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
    level="DEBUG" if settings.DEBUG else "INFO",
)
logger.add(
    "logs/wiggleai.log",
    rotation="50 MB",
    retention="7 days",
    compression="gz",
    level="INFO",
)
