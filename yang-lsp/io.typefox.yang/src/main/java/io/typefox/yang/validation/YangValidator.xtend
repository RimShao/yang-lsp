/*
 * generated by Xtext 2.13.0-SNAPSHOT
 */
package io.typefox.yang.validation

import com.google.inject.Inject
import com.google.inject.Singleton
import io.typefox.yang.utils.YangExtensions
import io.typefox.yang.utils.YangNameUtils
import io.typefox.yang.utils.YangTypesExtensions
import io.typefox.yang.yang.AbstractModule
import io.typefox.yang.yang.Base
import io.typefox.yang.yang.Enum
import io.typefox.yang.yang.FractionDigits
import io.typefox.yang.yang.Import
import io.typefox.yang.yang.Include
import io.typefox.yang.yang.Key
import io.typefox.yang.yang.Mandatory
import io.typefox.yang.yang.MaxElements
import io.typefox.yang.yang.MinElements
import io.typefox.yang.yang.Modifier
import io.typefox.yang.yang.OrderedBy
import io.typefox.yang.yang.Pattern
import io.typefox.yang.yang.Refinable
import io.typefox.yang.yang.Revision
import io.typefox.yang.yang.Statement
import io.typefox.yang.yang.Type
import io.typefox.yang.yang.Typedef
import io.typefox.yang.yang.YangVersion
import org.eclipse.emf.ecore.xml.type.internal.RegEx.ParseException
import org.eclipse.emf.ecore.xml.type.internal.RegEx.RegularExpression
import org.eclipse.xtext.validation.Check

import static com.google.common.base.CharMatcher.*
import static io.typefox.yang.utils.YangExtensions.*
import static io.typefox.yang.validation.IssueCodes.*
import static io.typefox.yang.yang.YangPackage.Literals.*

import static extension com.google.common.base.Strings.nullToEmpty
import static extension io.typefox.yang.utils.IterableExtensions2.toMultimap
import static extension io.typefox.yang.utils.YangDateUtils.*

/**
 * This class contains custom validation rules for the YANG language. 
 */
@Singleton
class YangValidator extends AbstractYangValidator {

	@Inject
	extension YangExtensions;

	@Inject
	extension YangTypesExtensions;

	@Inject
	extension YangEnumerableValidator;

	@Inject
	SubstatementRuleProvider substatementRuleProvider;

	@Inject
	SubstatementFeatureMapper featureMapper;

	@Check
	def void checkVersion(YangVersion it) {
		if (yangVersion != YANG_1 && yangVersion != YANG_1_1) {
			val message = '''The version must be either "«YANG_1»" or "YANG_1_1»".''';
			error(message, it, YANG_VERSION__YANG_VERSION, INCORRECT_VERSION);
		}
	}

	@Check
	def void checkVersionConsistency(AbstractModule it) {
		// https://tools.ietf.org/html/rfc7950#section-12
		// A YANG version 1.1 module must not include a YANG version 1 submodule, and a YANG version 1 module must not include a YANG version 1.1 submodule.
		val moduleVersion = yangVersion;
		substatementsOfType(Include).map[module].filterNull.filter[eResource !== null && !eIsProxy].filter [
			yangVersion != moduleVersion
		].forEach [
			val message = '''Cannot include a version «yangVersion» submodule in a version «moduleVersion» module.''';
			error(message, it, ABSTRACT_IMPORT__MODULE, BAD_INCLUDE_YANG_VERSION);
		];

		// A YANG version 1 module or submodule must not import a YANG version 1.1 module by revision.	
		if (moduleVersion == YANG_1) {
			substatementsOfType(Import).map[module].filterNull.filter[eResource !== null && !eIsProxy].filter [
				yangVersion != moduleVersion
			].forEach [
				val message = '''Cannot import a version «yangVersion» submodule in a version «moduleVersion» module.''';
				error(message, it, ABSTRACT_IMPORT__MODULE, BAD_IMPORT_YANG_VERSION);
			];
		}
	}

	@Check
	def void checkSubstatements(Statement it) {
		substatementRuleProvider.get(eClass)?.checkSubstatements(it, this, featureMapper);
	}

	@Check
	def void checkTypeRestriction(Type it) {
		// https://tools.ietf.org/html/rfc7950#section-9.2.3
		// https://tools.ietf.org/html/rfc7950#section-9.3.3
		// Same for string it just has another statement name.
		// https://tools.ietf.org/html/rfc7950#section-9.4.3
		val refinements = substatementsOfType(Refinable);
		if (!refinements.nullOrEmpty) {
			val expectedRefinementKind = refinementKind;
			refinements.forEach [
				if (expectedRefinementKind === null || !(expectedRefinementKind.isAssignableFrom(it.class))) {
					val message = '''Type cannot have "«YangNameUtils.getYangName(it.eClass)»" restriction statement.''';
					error(message, it, REFINABLE__EXPRESSION, TYPE_ERROR);
				}
			];
		}
	}

	@Check
	def checkRefinement(Refinable it) {
		val yangRefinable = yangRefinable;
		if (yangRefinable !== null) {
			yangRefinable.validate(this);
		}
	}

	@Check
	def checkUnionType(Type it) {
		if (union) {
			// At least one `type` sub-statement should be present for each `union` type.
			// https://tools.ietf.org/html/rfc7950#section-9.12
			if (substatementsOfType(Type).nullOrEmpty) {
				val message = '''Type substatement must be present for each union type.''';
				error(message, it, TYPE__TYPE_REF, TYPE_ERROR);
			}
		}
	}

	@Check
	def checkIdentityrefType(Type it) {
		if (identityref) {
			// The "base" statement, which is a sub-statement to the "type" statement, 
			// must be present at least once if the type is "identityref".
			// https://tools.ietf.org/html/rfc7950#section-9.10.2
			if (substatementsOfType(Base).nullOrEmpty) {
				val message = '''The "base" statement must be present at least once for all "identityref" types''';
				error(message, it, TYPE__TYPE_REF, TYPE_ERROR);
			}
		}
	}

	@Check
	def checkEnumerables(Type it) {
		validateEnumerable(this);
	}

	@Check
	def checkEnumeration(Type type) {
		val enums = type.substatementsOfType(Enum);
		if (!type.subtypeOfEnumeration) {
			enums.forEach [
				val message = '''Only enumeration types can have a "enum" statement.''';
				error(message, type, TYPE__TYPE_REF, TYPE_ERROR);
			];
		} else {
			enums.forEach [
				val message = if (name.length === 0) {
						'''The name must not be zero-length.'''
					} else if (name != WHITESPACE.or(BREAKING_WHITESPACE).trimFrom(name)) {
						'''The name must not have any leading or trailing whitespace characters.'''
					} else {
						null;
					}
				if (message !== null) {
					error(message, it, ENUMERABLE__NAME, TYPE_ERROR);
				}
			];
		}
	}

	@Check
	def checkFractionDigitsExist(Type it) {
		// https://tools.ietf.org/html/rfc7950#section-9.3.4
		val fractionDigits = firstSubstatementsOfType(FractionDigits);
		val fractionDigitsExist = fractionDigits !== null;
		// Note, only the decimal type definition MUST have the `fraction-digits` statement.
		// It is not mandatory for types that are derived from decimal built-ins. 
		val decimalBuiltin = decimal;
		if (decimalBuiltin) {
			if (fractionDigitsExist) {
				// Validate the fraction digits. It takes as an argument an integer between 1 and 18, inclusively.
				val value = fractionDigitsAsInt;
				if (value.intValue < 1 || value.intValue > 18) {
					val message = '''The "fraction-digits" value must be an integer between 1 and 18, inclusively.''';
					error(message, fractionDigits, FRACTION_DIGITS__RANGE, TYPE_ERROR);
				}

			} else {
				// Decimal types must have fraction-digits sub-statement.
				val message = '''The "fraction-digits" statement must be present for "decimal64" types.''';
				error(message, it, TYPE__TYPE_REF, TYPE_ERROR);
			}
		} else {
			if (fractionDigitsExist) {
				val message = '''Only decimal64 types can have a "fraction-digits" statement.''';
				error(message, it, TYPE__TYPE_REF, TYPE_ERROR);
			}
		}
	}

	@Check
	def checkPattern(Pattern it) {
		// https://tools.ietf.org/html/rfc7950#section-9.4.5
		if (eContainer instanceof Type) {
			val type = eContainer as Type;
			if (type.subtypeOfString) {
				try {
					new RegularExpression(regexp.nullToEmpty, 'X');
				} catch (ParseException e) {
					val message = if (regexp.nullOrEmpty) {
							'Regular expression must be specified.'
						} else {
							'''Invalid regular expression pattern: "«regexp»".''';
						}
					error(message, it, PATTERN__REGEXP, TYPE_ERROR);
				}
			} else {
				val message = '''Only string types can have a "pattern" statement.''';
				error(message, type, TYPE__TYPE_REF, TYPE_ERROR);
			}
		}
	}

	@Check
	def checkModifier(Modifier it) {
		// https://tools.ietf.org/html/rfc7950#section-9.4.6
		if (modifier != 'invert-match') {
			val message = '''Modifier value must be "invert-match".''';
			error(message, it, MODIFIER__MODIFIER, TYPE_ERROR);
		}
	}

	@Check
	def checkRevisionFormat(Revision it) {
		if (revision !== null) {
			try {
				revisionDateFormat.parse(revision);
			} catch (java.text.ParseException e) {
				val message = '''The revision date string should be in the following format: "YYYY-MM-DD".''';
				warning(message, it, REVISION__REVISION, INVALID_REVISION_FORMAT);
			}
		}
	}

	@Check
	def checkRevisionOrder(AbstractModule it) {
		val revisions = substatementsOfType(Revision).toList;
		for (index : 1 ..< revisions.size) {
			val previous = revisions.get(index - 1);
			val current = revisions.get(index);
			if (current.isGreaterThan(previous)) {
				val message = '''The revision statement is not given in reverse chronological order.''';
				warning(message, current, REVISION__REVISION, REVISION_ORDER);
			}
		}
	}

	@Check
	def checkTypedef(Typedef it) {
		// The [1..*] type cardinality is checked by other rules.
		// Also, the type name uniqueness is checked in the scoping. 
		// https://tools.ietf.org/html/rfc7950#section-7.3
		if (name.builtinName) {
			val message = '''Illegal type name "«name»".''';
			error(message, it, SCHEMA_NODE__NAME, BAD_TYPE_NAME);
		}
	}

	@Check
	def checkMandatoryValue(Mandatory it) {
		// https://tools.ietf.org/html/rfc7950#section-7.6.5
		// The value can be either `true` or `false`. If missing, then `false` by default.
		if (isMandatory !== null) {
			val validValues = #{"true", "false"};
			if (!validValues.contains(isMandatory)) {
				val message = '''The argument of the "mandatory" statement must be either "true" or "false".''';
				error(message, it, MANDATORY__IS_MANDATORY, TYPE_ERROR);
			}
		}
	}

	@Check
	def checkMinElements(MinElements it) {
		// https://tools.ietf.org/html/rfc7950#section-7.7.5
		val expectedElements = minElements.parseIntSafe;
		if (expectedElements === null || expectedElements.intValue < 0) {
			val message = '''The value of the "min-elements" must be a non-negative integer.''';
			error(message, it, MIN_ELEMENTS__MIN_ELEMENTS, TYPE_ERROR);
		}
	}

	@Check
	def chechMaxElements(MaxElements it) {
		// https://tools.ietf.org/html/rfc7950#section-7.7.6
		if (maxElements != 'unbounded') {
			val expectedElements = maxElements.parseIntSafe;
			if (expectedElements === null || expectedElements.intValue < 1) {
				val message = '''The value of the "max-elements" must be a positive integer or the string "unbounded".''';
				error(message, it, MIN_ELEMENTS__MIN_ELEMENTS, TYPE_ERROR);
			}
		}
	}

	@Check
	def checkOrderedBy(OrderedBy it) {
		// https://tools.ietf.org/html/rfc7950#section-7.7.7
		if (orderedBy !== null) {
			val validValues = #{"system", "user"};
			if (!validValues.contains(orderedBy)) {
				val message = '''The argument of the "ordered-by" statement must be either "system" or "user".''';
				error(message, it, ORDERED_BY__ORDERED_BY, TYPE_ERROR);
			}
		}
	}

	@Check
	def checkKey(Key key) {
		// https://tools.ietf.org/html/rfc7950#section-7.8.2	
		// A leaf identifier must not appear more than once in the key.
		key.references.filter[!node?.name.nullOrEmpty].toMultimap[node.name].asMap.forEach [ name, nodesWithSameName |
			if (nodesWithSameName.size > 1) {
				nodesWithSameName.forEach [
					val message = '''The leaf identifier "«name»" must not appear more than once in a key.''';
					val index = key.references.indexOf(it);
					error(message, key, KEY__REFERENCES, index, KEY_DUPLICATE_LEAF_NAME);
				];
			}
		];
	}

	private def getParseIntSafe(String it) {
		return try {
			if(nullOrEmpty) null else Integer.parseInt(it);
		} catch (NumberFormatException e) {
			null;
		}
	}

}
