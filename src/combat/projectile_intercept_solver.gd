class_name ProjectileInterceptSolver
extends RefCounted
const EPS:=0.000001
static func solve(sp:Vector3,sv:Vector3,tp:Vector3,tv:Vector3,speed:float)->ProjectileInterceptResult:
 if not sp.is_finite() or not sv.is_finite() or not tp.is_finite() or not tv.is_finite() or not is_finite(speed) or speed<=EPS:return ProjectileInterceptResult.invalid()
 var rp:=tp-sp;var rv:=tv-sv;var a:=rv.dot(rv)-speed*speed;var b:=2.0*rp.dot(rv);var c:=rp.dot(rp);var t:=_root(a,b,c)
 if t<=EPS or not is_finite(t):return ProjectileInterceptResult.invalid()
 var point:=tp+tv*t;var rel:=point-sp-sv*t
 if not rel.is_finite() or rel.length_squared()<=EPS:return ProjectileInterceptResult.invalid()
 return ProjectileInterceptResult.solved(t,point,rel.normalized())
static func _root(a:float,b:float,c:float)->float:
 if absf(a)<=EPS:
  if absf(b)<=EPS:return -1.0
  var x:=-c/b;return x if x>EPS else -1.0
 var disc:=b*b-4*a*c
 if disc<0 or not is_finite(disc):return -1.0
 var q:=sqrt(maxf(disc,0));var t1:=(-b-q)/(2*a);var t2:=(-b+q)/(2*a);var best:=INF
 if t1>EPS:best=t1
 if t2>EPS:best=minf(best,t2)
 return best if is_finite(best) else -1.0
