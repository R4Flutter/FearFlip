import 'object_pool.dart';

class PooledEnemy {
  double x = 0;
  double y = 0;
  bool active = false;
}

class PooledParticle {
  double x = 0;
  double y = 0;
  double life = 0;
}

class PooledEffect {
  String id = '';
  bool playing = false;
}

class EnginePools {
  EnginePools()
    : enemies = ObjectPool<PooledEnemy>(create: PooledEnemy.new),
      particles = ObjectPool<PooledParticle>(create: PooledParticle.new),
      effects = ObjectPool<PooledEffect>(create: PooledEffect.new);

  final ObjectPool<PooledEnemy> enemies;
  final ObjectPool<PooledParticle> particles;
  final ObjectPool<PooledEffect> effects;
}
