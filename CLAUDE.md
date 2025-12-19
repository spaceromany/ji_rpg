# CLAUDE.md - AI 어시스턴트 가이드

이 문서는 Claude Code가 프로젝트를 이해하고 효과적으로 도움을 제공하기 위한 가이드입니다.

## 프로젝트 개요

옥토패스 트래블러 스타일의 턴제 RPG 게임입니다. Godot 4.5 + GDScript로 개발 중입니다.

## 핵심 아키텍처

### 게임 흐름
```
GameManager (scenes/game/game_manager.tscn)
    ├── FieldMap (필드 맵 - 실시간)
    │   └── 전투 조우 시 → BattleScene 전환
    └── BattleScene (전투 씬 - 턴제)
        └── 전투 종료 시 → FieldMap 복귀
```

### 전투 시스템 구조
```
BattleManager
    ├── TurnManager (턴 순서 관리)
    ├── DamageCalculator (데미지 계산)
    └── Battler[] (전투 참가자)
        ├── BattlerData (스탯/스킬 데이터)
        └── 상태 관리 (HP, SP, BP, Shield)
```

## 주요 파일 설명

### 데이터 (scripts/data/)
| 파일 | 설명 |
|------|------|
| `enums.gd` | 게임 전역 열거형 (StatType, TargetType, EffectType, BattlerState) |
| `battler_data.gd` | 배틀러 스탯 리소스 |
| `skill_data.gd` | 스킬 데이터 리소스 |
| `sample_data.gd` | 테스트용 샘플 데이터 생성 |

### 전투 (scripts/battle/)
| 파일 | 설명 |
|------|------|
| `battle_manager.gd` | 전투 전체 흐름 관리 (핵심) |
| `turn_manager.gd` | 턴 순서 계산 및 관리 |
| `battler.gd` | 개별 전투 참가자 로직 |
| `damage_calculator.gd` | 데미지/힐 공식 계산 |
| `test_battle_scene.gd` | 전투 씬 UI 통합 |

### 필드 (scripts/field/)
| 파일 | 설명 |
|------|------|
| `field_map.gd` | 필드 맵 메인 로직 |
| `field_unit.gd` | 필드 유닛 이동/선택 |
| `field_unit_data.gd` | 필드 유닛 데이터 |
| `support_range_drawer.gd` | 지원 범위 시각화 |

### UI (scripts/ui/)
| 파일 | 설명 |
|------|------|
| `command_ui.gd` | 공격/스킬/방어 커맨드 메뉴 |
| `turn_order_ui.gd` | 상단 턴 순서 표시 |
| `target_selector_ui.gd` | 타겟 선택 UI |
| `battler_status_ui.gd` | 플레이어 상태 표시 |
| `enemy_status_ui.gd` | 적 상태 표시 |

## 코드 패턴 및 규칙

### 시그널 사용
- 컴포넌트 간 통신은 시그널 사용
- 예: `battle_started`, `turn_started`, `action_executed`

### 비동기 처리
- 전투 턴 처리는 `await` 사용
- `is_processing_turn` 플래그로 중복 실행 방지

### 상태 관리
- `BattleState` enum으로 전투 상태 관리
- `BattlerState` enum으로 배틀러 상태 관리

## 주의사항

### 턴 시스템
- `turn_manager.advance_turn()` 호출 전에 `is_processing_turn = false` 설정 필수
- `on_battler_broke()`에서 턴 순서 전체 재계산 금지 (해당 배틀러만 맨 뒤로 이동)

### 씬 전환
- 필드 → 전투 전환 시 카메라 줌 리셋 (1.0)
- 전투 → 필드 복귀 시 저장된 줌 레벨 복원

### 입력 처리
- `Input.is_action_just_pressed()` 사용
- UI 입력은 `_input()` 에서 처리 후 `set_input_as_handled()` 호출

## 디버깅

디버그 로그 패턴:
```gdscript
print("[ClassName] message: %s" % variable)
```

주요 디버그 포인트:
- `[TurnManager]` - 턴 순서 변경
- `[BattleManager]` - 전투 흐름
- `[FieldUnit]` - 유닛 이동/선택

## 자주 발생하는 이슈

1. **턴 스킵 문제**: `is_processing_turn` 플래그 확인
2. **줌 유지 문제**: `GameManager`의 `saved_zoom_level` 확인
3. **시그널 중복 호출**: 시그널 연결 시 `CONNECT_ONE_SHOT` 고려

## 테스트 방법

1. Godot 에디터에서 `scenes/game/game_manager.tscn` 실행
2. 필드 맵에서 유닛 이동 테스트
3. 적과 조우하여 전투 테스트
4. 전투 승리/패배 후 필드 복귀 확인
