
TextureLoad :: (fileName: string, textureType: string) -> Texture, bool
{
	texture: Texture;
	texture.Type = textureType;

	path := tprint("%/../textures/%", #filepath, fileName);

	width, height, channels: s32;

	stbi_set_flip_vertically_on_load(1);
	data := stbi_load(temp_c_string(path), *width, *height, *channels, 4);

	if !data
	{
		print("Failed to load a texture (%).\n", path);
		return texture, false;
	}
	defer stbi_image_free(data);

	glGenTextures(1, *texture.ID);
	glBindTexture(GL_TEXTURE_2D, texture.ID);

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
	glGenerateMipmap(GL_TEXTURE_2D);

	_TextureSetParameters();

	glBindTexture(GL_TEXTURE_2D, 0);

	return texture, true;
}

TextureCreateSolid :: (r: u8, g: u8, b: u8, textureType: string) -> Texture
{
	texture: Texture;
	texture.Type = textureType;

	pixel: [4] u8;
	pixel[0] = r;
	pixel[1] = g;
	pixel[2] = b;
	pixel[3] = 255;

	glGenTextures(1, *texture.ID);
	glBindTexture(GL_TEXTURE_2D, texture.ID);

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, *pixel[0]);

	_TextureSetParameters();

	glBindTexture(GL_TEXTURE_2D, 0);

	return texture;
}

_TextureSetParameters :: ()
{
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
}

Texture :: struct
{
	ID: u32;
	Type: string;
}

#import "Basic";
#import "GL";
#import "stb_image";
