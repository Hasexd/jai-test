
CameraMovement :: enum
{
	FORWARD;
	BACKWARD;
	LEFT;
	RIGHT;
}

Camera :: struct
{
	Position: Vector3;
	Front: Vector3;
	Up: Vector3;
	Right: Vector3;
	WorldUp: Vector3;

	Yaw: float32;
	Pitch: float32;

	MovementSpeed: float32;
	MouseSensitivity: float32;
	Fov: float32;
}

CameraInit :: (self: *Camera, position: Vector3)
{
	self.Position = position;
	self.WorldUp = Vector3.{ 0.0, 1.0, 0.0 };

	self.Yaw = -90.0;
	self.Pitch = 0.0;

	self.MovementSpeed = 2.5;
	self.MouseSensitivity = 0.1;
	self.Fov = 45.0;

	_CameraUpdateVectors(self);
}

CameraProcessKeyboard :: (self: *Camera, direction: CameraMovement, deltaTime: float32)
{
	velocity := self.MovementSpeed * deltaTime;

	if direction == {
		case .FORWARD;  self.Position += self.Front * velocity;
		case .BACKWARD; self.Position -= self.Front * velocity;
		case .LEFT;     self.Position -= self.Right * velocity;
		case .RIGHT;    self.Position += self.Right * velocity;
	}
}

CameraProcessMouse :: (self: *Camera, xOffset: float32, yOffset: float32)
{
	self.Yaw += xOffset * self.MouseSensitivity;
	self.Pitch += yOffset * self.MouseSensitivity;
	
	Clamp(*self.Pitch, -89.0, 89.0);

	_CameraUpdateVectors(self);
}

CameraGetViewMatrix :: (self: *Camera) -> Matrix4
{
	r := self.Right;
	u := self.Up;
	f := self.Front;
	p := self.Position;

	view := Matrix4_Identity;

	view.coef[0][0] = r.x;  view.coef[0][1] = r.y;  view.coef[0][2] = r.z;  view.coef[0][3] = -dot(r, p);
	view.coef[1][0] = u.x;  view.coef[1][1] = u.y;  view.coef[1][2] = u.z;  view.coef[1][3] = -dot(u, p);
	view.coef[2][0] = -f.x; view.coef[2][1] = -f.y; view.coef[2][2] = -f.z; view.coef[2][3] = dot(f, p);

	return view;
}

CameraGetProjectionMatrix :: (self: *Camera, aspect: float32, near: float32 = 0.1, far: float32 = 100.0) -> Matrix4
{
	f := 1.0 / tan(_ToRadians(self.Fov) * 0.5);

	proj: Matrix4;

	proj.coef[0][0] = f / aspect;
	proj.coef[1][1] = f;
	proj.coef[2][2] = (far + near) / (near - far);
	proj.coef[2][3] = (2.0 * far * near) / (near - far);
	proj.coef[3][2] = -1.0;

	return proj;
}


_CameraUpdateVectors :: (self: *Camera)
{
	yaw := _ToRadians(self.Yaw);
	pitch := _ToRadians(self.Pitch);

	front: Vector3;
	front.x = cos(yaw) * cos(pitch);
	front.y = sin(pitch);
	front.z = sin(yaw) * cos(pitch);

	self.Front = normalize(front);
	self.Right = normalize(cross(self.Front, self.WorldUp));
	self.Up = normalize(cross(self.Right, self.Front));
}

_ToRadians :: (degrees: float32) -> float32
{
	return degrees * (PI / 180.0);
}

#import "Math";
