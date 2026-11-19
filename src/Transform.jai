
MakeTranslation :: (v: Vector3) -> Matrix4
{
	m := Matrix4_Identity;

	m.coef[0][3] = v.x;
	m.coef[1][3] = v.y;
	m.coef[2][3] = v.z;

	return m;
}

MakeScale :: (v: Vector3) -> Matrix4
{
	m := Matrix4_Identity;

	m.coef[0][0] = v.x;
	m.coef[1][1] = v.y;
	m.coef[2][2] = v.z;

	return m;
}

MakeRotation :: (axis: Vector3, radians: float32) -> Matrix4
{
	a := normalize(axis);
	c := cos(radians);
	s := sin(radians);
	t := 1.0 - c;

	m := Matrix4_Identity;

	m.coef[0][0] = c + a.x * a.x * t;
	m.coef[0][1] = a.x * a.y * t - a.z * s;
	m.coef[0][2] = a.x * a.z * t + a.y * s;

	m.coef[1][0] = a.y * a.x * t + a.z * s;
	m.coef[1][1] = c + a.y * a.y * t;
	m.coef[1][2] = a.y * a.z * t - a.x * s;

	m.coef[2][0] = a.z * a.x * t - a.y * s;
	m.coef[2][1] = a.z * a.y * t + a.x * s;
	m.coef[2][2] = c + a.z * a.z * t;

	return m;
}

#import "Math";
