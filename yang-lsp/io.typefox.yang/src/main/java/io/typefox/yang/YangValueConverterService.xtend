package io.typefox.yang

import com.google.inject.Inject
import org.eclipse.xtext.conversion.IValueConverter
import org.eclipse.xtext.conversion.ValueConverter
import org.eclipse.xtext.conversion.ValueConverterException
import org.eclipse.xtext.conversion.impl.AbstractDeclarativeValueConverterService
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.AbstractRule
import java.util.regex.Pattern

class YangValueConverterService extends AbstractDeclarativeValueConverterService {
	
	@Inject
	private StringConverter stringValueConverter;
	
	@ValueConverter(rule = "io.typefox.yang.Yang.StringValue")
	public def IValueConverter<String> StringValue() {
		return stringValueConverter;
	}
	
	@ValueConverter(rule = "StringValue")
	public def IValueConverter<String> StringValue2() {
		return stringValueConverter;
	}
	
	static class StringConverter implements IValueConverter<String>, IValueConverter.RuleSpecific {
		
		static Pattern ID_MATCH = Pattern.compile(".*[\\s'\";\\{\\}]+.*");
		override toString(String value) throws ValueConverterException {
			if (ID_MATCH.matcher(value).matches) {
				return "'"+value+"'"
			}
			return value
		}
		
		static val char[] quotes = #['"','\'']
		
		override toValue(String string, INode node) throws ValueConverterException {
			val result = new StringBuilder
			for (n : node.leafNodes) {
				if (!n.hidden) {
					val seg = n.text 					
					if (seg.length>=2) {
						val first = seg.charAt(0)
						if (quotes.contains(first) && seg.charAt(seg.length-1) === first) {
							result.append(seg.substring(1, seg.length-1))
						} else {
							result.append(seg)
						}
					} else {
						result.append(seg)
					}
				}
			}
			return result.toString
		}
		
		AbstractRule rule
		
		override setRule(AbstractRule rule) throws IllegalArgumentException {
			this.rule = rule
		}
		
	}	
	
	@Inject
	private StringConverter numberValueConverter;
	
	@ValueConverter(rule = "io.typefox.yang.Yang.NUMBER")
	public def IValueConverter<String> NUMBERValue() {
		return numberValueConverter;
	}
	
	@ValueConverter(rule = "NUMBER")
	public def IValueConverter<String> NUMBERValue2() {
		return numberValueConverter;
	}
	
	static class NumberConverter implements IValueConverter<String>, IValueConverter.RuleSpecific {
		
		override toString(String value) throws ValueConverterException {
			return value
		}
		
		override toValue(String string, INode node) throws ValueConverterException {
			try {
				Double.parseDouble(string);
			} catch (NumberFormatException e) {
				throw new ValueConverterException("Couldn't convert '" + string + "' to an double value.", node, e);
			}
			return string
		}
		
		AbstractRule rule
		
		override setRule(AbstractRule rule) throws IllegalArgumentException {
			this.rule = rule
		}
		
	}
}