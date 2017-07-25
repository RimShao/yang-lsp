package io.typefox.yang.formatting2

import com.google.inject.Inject
import io.typefox.yang.services.YangGrammarAccess
import io.typefox.yang.yang.Contact
import io.typefox.yang.yang.Description
import io.typefox.yang.yang.Module
import io.typefox.yang.yang.Namespace
import io.typefox.yang.yang.Organization
import io.typefox.yang.yang.Prefix
import io.typefox.yang.yang.Reference
import io.typefox.yang.yang.Revision
import io.typefox.yang.yang.Statement
import io.typefox.yang.yang.YangVersion
import java.util.List
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.Assignment
import org.eclipse.xtext.formatting2.AbstractFormatter2
import org.eclipse.xtext.formatting2.FormatterPreferenceKeys
import org.eclipse.xtext.formatting2.FormatterRequest
import org.eclipse.xtext.formatting2.IFormattableDocument
import org.eclipse.xtext.formatting2.ITextReplacer
import org.eclipse.xtext.formatting2.ITextReplacerContext
import org.eclipse.xtext.formatting2.regionaccess.ISemanticRegion
import org.eclipse.xtext.formatting2.regionaccess.ITextSegment
import org.eclipse.xtext.formatting2.regionaccess.internal.TextSegment
import org.eclipse.xtext.preferences.MapBasedPreferenceValues
import io.typefox.yang.yang.Typedef
import io.typefox.yang.yang.Value
import io.typefox.yang.yang.Type

class YangFormatter extends AbstractFormatter2 {
    
    @Inject extension YangGrammarAccess
    
    // Defaults

    static val INDENTATION = "  "
    public static val MAX_LINE_LENGTH = 72

    override protected initialize(FormatterRequest request) {
        val preferences = request.preferences
        if (preferences instanceof MapBasedPreferenceValues) {
            preferences.put(FormatterPreferenceKeys.indentation, INDENTATION)
        }
        super.initialize(request)
    }
    
    // Rules

    def dispatch void format(Module m, extension IFormattableDocument it) {
        m.regionFor.assignment(moduleAccess.nameAssignment_1).surround[oneSpace]
        formatStatement(m)
    }

    def dispatch void format(YangVersion v, extension IFormattableDocument it) {
        v.regionFor.assignment(yangVersionAccess.yangVersionAssignment_1).surround[oneSpace]
        formatStatement(v)
    }
    
    def dispatch void format(Namespace ns, extension IFormattableDocument it) {
        ns.regionFor.assignment(namespaceAccess.uriAssignment_1).surround[oneSpace]
        formatStatement(ns)
    }
    
    def dispatch void format(Prefix p, extension IFormattableDocument it) {
        p.regionFor.assignment(prefixAccess.prefixAssignment_1).surround[oneSpace]
        formatStatement(p)
    }
    
    def dispatch void format(Organization o, extension IFormattableDocument it) {
        formatMultilineString(o, organizationAccess.organizationAssignment_1)
        formatStatement(o)
    }
    
    def dispatch void format(Description d, extension IFormattableDocument it) {
        formatMultilineString(d, descriptionAccess.descriptionAssignment_1)
        formatStatement(d)
    }
    
    def dispatch void format(Contact c, extension IFormattableDocument it) {
        formatMultilineString(c, contactAccess.contactAssignment_1)
        formatStatement(c)
    }
    
    def dispatch void format(Reference r, extension IFormattableDocument it) {
        formatMultilineString(r, referenceAccess.referenceAssignment_1)
        formatStatement(r)
    }
    
    def dispatch void format(Revision r, extension IFormattableDocument it) {
        r.regionFor.assignment(revisionAccess.revisionAssignment_1).surround[oneSpace]
        formatStatement(r)
    }
    
    def dispatch void format(Typedef t, extension IFormattableDocument it) {
        t.regionFor.assignment(typedefAccess.nameAssignment_1).surround[oneSpace]
        formatStatement(t)
    }
    
    def dispatch void format(Type t, extension IFormattableDocument it) {
        val typeRef = t.typeRef
        if (typeRef !== null) {
            typeRef.regionFor.assignment(typeReferenceAccess.typeAssignment_1).surround[oneSpace]
            typeRef.regionFor.crossRef(typeReferenceAccess.typeTypedefCrossReference_1_0).surround[oneSpace]
        }
        formatStatement(t)
    }
    
    def dispatch void format(io.typefox.yang.yang.Enum e, extension IFormattableDocument it) {
        e.regionFor.assignment(enumAccess.nameAssignment_1).surround[oneSpace]
        formatStatement(e)
        
    }
    
    def dispatch void format(Value v, extension IFormattableDocument it) {
        v.regionFor.assignment(valueAccess.ordinalAssignment_1).surround[oneSpace]
        formatStatement(v)
    }
    
    // Tools
    
    def formatMultilineString(extension IFormattableDocument it, Statement s, Assignment a) {
        val textRegion = s.regionFor.assignment(a).prepend[newLine].textRegion
        addReplacer(new MultilineStringReplacer(textRegion))
    }
    
    def void formatStatement(extension IFormattableDocument it, Statement s) {
        s.regionFor.keyword(statementEndAccess.semicolonKeyword_1)
            .prepend[noSpace; highPriority]
            
        val leftCurly = s.regionFor.keyword(statementEndAccess.leftCurlyBracketKeyword_0_0)
        val rightCurly = s.regionFor.keyword(statementEndAccess.rightCurlyBracketKeyword_0_2)

        interior(
            leftCurly,
            rightCurly.prepend[newLine]
        ) [indent]
        // continue
        formatSubstatements(s)
    }
    
    def formatSubstatements(extension IFormattableDocument it, Statement s) {
        val condensed = s instanceof io.typefox.yang.yang.Enum
        	
        for (substatement : s.substatements) {
            if (condensed) {
                substatement.prepend[setNewLines(1, 1, 2)]
            } else {
                substatement.prepend[setNewLines(2, 2, 3)]
            }
            substatement.format
        }
    }
    
    def TextSegment textRegion(ISemanticRegion region) {
        return new TextSegment(getTextRegionAccess(), region.offset, region.length)
    }
    
}

@FinalFieldsConstructor
class MultilineStringReplacer implements ITextReplacer {
    val TextSegment segment

    override ITextSegment getRegion() {
        segment
    }
    
    override createReplacements(ITextReplacerContext context) {
        val defaultIndentation = context.formatter.preferences.getPreference(FormatterPreferenceKeys.indentation)
        val currentIndentation = context.indentationString
        val indentation = currentIndentation + defaultIndentation
        val original = segment.text
        val splitted = original.substring(1, original.length - 1).split("(\\s(?=\\S)|\\n(?!' '))")
        var currentLine = <String> newLinkedList()
        val lines = <List<String>> newArrayList(currentLine)
        for (s : splitted) {
            val currentLength = currentLine.length
            if (currentLength + s.length > YangFormatter.MAX_LINE_LENGTH || s.length > YangFormatter.MAX_LINE_LENGTH) {
                lines += (currentLine = <String> newLinkedList())
            } else if (s.trim.empty) {
                lines += (currentLine = <String> newLinkedList())
            }
            if (currentLine.length > 0) {
                currentLine += " "
            }
            val word = s.ltrim
            if (!word.empty) {
                currentLine += word
            }
        }
        
        lines.head.add(0, defaultIndentation + '"')
        if (lines.size === 1) {
            lines.head += '"'
        }
        if (lines.size > 1) {
            lines.tail.take(lines.size - 1).forEach[
                add(0, indentation + " ")
            ]
        }
        if (lines.size > 1) {
            lines += <String> newLinkedList(indentation, '"')
        }
        val newText = lines.map[join()].join("\n")
        context.addReplacement(segment.replaceWith(newText))
        return context
    }
    
    static def length(List<String> strings)  {
        return strings.fold(0, [r, w| r + w.length])
    }
    
    static def String ltrim(String s) {
        val char space = ' '
        val beginIndex = (0..<s.length).findFirst[i | s.charAt(i) !== space]?:s.length
        return s.substring(beginIndex)
    }
    
}