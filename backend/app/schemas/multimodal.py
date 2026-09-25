"""Provider-independent multimodal message content schemas."""

from typing import Annotated, Literal, Union
from pydantic import Field

from app.schemas.common import BaseSchema


class TextContent(BaseSchema):
    """Standard text block within a multimodal message."""

    type: Literal["text"] = "text"
    text: str = Field(..., min_length=1)


class ImageAttachmentRef(BaseSchema):
    """Attachment reference used by orchestrator before media resolution.

    MUST NOT contain filesystem paths.
    """

    type: Literal["image_attachment"] = "image_attachment"
    attachment_id: str
    mime_type: str


class ResolvedImageContent(BaseSchema):
    """Resolved raw image bytes passed to provider translation layer."""

    type: Literal["image_bytes"] = "image_bytes"
    mime_type: str
    data: bytes = Field(..., min_length=1)


ContentBlock = Annotated[
    Union[TextContent, ResolvedImageContent],
    Field(discriminator="type"),
]
