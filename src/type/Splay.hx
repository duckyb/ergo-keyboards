package type;

/**
 * ...
 * @author YellowAfterlife
 */
abstract Splay(SplayBase) from SplayBase to SplayBase {
	@:from public static inline function fromBool(b:Null<Bool>):Splay {
		return b ? Yes : No;
	}
}
enum SplayBase {
	No;
	Yes;
	PinkyOnly;
	Optional;
}