package io.typefox.yang.ide.editor.syntaxcoloring

import com.google.common.base.Preconditions
import com.google.common.collect.ImmutableSet
import com.google.common.collect.Lists
import com.google.inject.Singleton
import io.typefox.yang.yang.Action
import io.typefox.yang.yang.Augment
import io.typefox.yang.yang.Default
import io.typefox.yang.yang.Description
import io.typefox.yang.yang.Deviation
import io.typefox.yang.yang.Extension
import io.typefox.yang.yang.Feature
import io.typefox.yang.yang.Identity
import io.typefox.yang.yang.Key
import io.typefox.yang.yang.Notification
import io.typefox.yang.yang.Refine
import io.typefox.yang.yang.Rpc
import org.eclipse.core.runtime.OperationCanceledException
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.xtext.ide.editor.syntaxcoloring.DefaultSemanticHighlightingCalculator
import org.eclipse.xtext.ide.editor.syntaxcoloring.IHighlightedPositionAcceptor
import org.eclipse.xtext.ide.server.semanticHighlight.ISemanticHighlightingStyleToTokenMapper
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.util.internal.Log

import static io.typefox.yang.yang.YangPackage.Literals.*
import io.typefox.yang.yang.Typedef
import com.google.inject.Inject
import io.typefox.yang.findReferences.YangReferenceFinder
import org.eclipse.emf.ecore.util.EcoreUtil

@Log
@Singleton
class YangSemanticHighlightingCalculator extends DefaultSemanticHighlightingCalculator implements ISemanticHighlightingStyleToTokenMapper {

	@Inject
	extension YangReferenceFinder;

	/**
	 * @noimplement
	 */
	static interface Styles {
		val EXTENDIBLE_MODULE_STATEMENT_STYLE = 'yang-extendible-module-statement';
		val INTERFACE_STATEMENT_STYLE = 'yang-interface-statement';
		val REFERENCEABLE_STATEMENT_STYLE = 'yang-referenceable-statement';
		// Other statements.
		val DESCRIPTION_STYLE = 'yang-description';
		val DEFAULT_STYLE = 'yang-default';
		val KEY_STYLE = 'key-default';
	}

	/**
	 * @noimplement
	 */
	static interface Scopes {
		// TODO: Adjust the scopes!!!
		val EXTENDIBLE_MODULE_STATEMENT_SCOPES = #['support.type.property-name.json', 'source.yang'];
		val INTERFACE_STATEMENT_SCOPES = #['punctuation.section.embedded.end.php', 'source.yang'];
		val REFERENCEABLE_STATEMENT_SCOPES = #['invalid', 'source.yang'];
		// Other statements.
		val DESCRIPTION_SCOPES = #['keyword.other.unit', 'source.yang'];
		val DEFAULT_SCOPES = #['keyword.other.unit', 'source.yang'];
		val KEY_SCOPES = #['keyword.other.unit', 'source.yang'];
	}

	public static val STYLE_MAPPINGS = #{
		Styles.EXTENDIBLE_MODULE_STATEMENT_STYLE -> Scopes.EXTENDIBLE_MODULE_STATEMENT_SCOPES,
		Styles.INTERFACE_STATEMENT_STYLE -> Scopes.INTERFACE_STATEMENT_SCOPES,
		Styles.REFERENCEABLE_STATEMENT_STYLE -> Scopes.REFERENCEABLE_STATEMENT_SCOPES,
		// Other statements.
		Styles.DESCRIPTION_STYLE -> Scopes.DESCRIPTION_SCOPES,
		Styles.DEFAULT_STYLE -> Scopes.DEFAULT_SCOPES,
		Styles.KEY_STYLE -> Scopes.KEY_SCOPES
	};

	override protected highlightElement(EObject object, IHighlightedPositionAcceptor acceptor,
		CancelIndicator cancelIndicator) {

		if (cancelIndicator.canceled) {
			throw new OperationCanceledException();
		}
		return object.doHighlightElement(acceptor);
	}

	protected dispatch def boolean doHighlightElement(EObject it, IHighlightedPositionAcceptor acceptor) {
		return false;
	}

	/*
	 * 2.
	 * Extendible module statement:
	 * Augment, Refine and Deviation statements have the ability to extend/impact (Add, Replace, Remove, Disable) existing modules.
	 * All of them can change specific existing module, and then a new derived module will be used in runtime.
	 * The difference between them is that they have their own extending target and extending ways.
	 * Therefore, it is important to highlight these extending part of a module.
	 */
	protected dispatch def boolean doHighlightElement(Augment it, IHighlightedPositionAcceptor acceptor) {
		return doHighlightNodeForFeature(acceptor, AUGMENT__PATH, Styles.EXTENDIBLE_MODULE_STATEMENT_STYLE);
	}

	protected dispatch def boolean doHighlightElement(Refine it, IHighlightedPositionAcceptor acceptor) {
		return doHighlightNodeForFeature(acceptor, REFINE__NODE, Styles.EXTENDIBLE_MODULE_STATEMENT_STYLE);
	}

	protected dispatch def boolean doHighlightElement(Deviation it, IHighlightedPositionAcceptor acceptor) {
		return doHighlightNodeForFeature(acceptor, DEVIATION__REFERENCE, Styles.EXTENDIBLE_MODULE_STATEMENT_STYLE);
	}

	/*
	 * 4.
	 * Interface statement:
	 * There are Action/RPC/Notification statement in yang modeling language. Apparently, they are quite different comparing with data nodes.
	 * They are interface (Operation/Notification) definition of some models. It makes sense to distinguish them apart from data nodes.
	 */
	protected dispatch def boolean doHighlightElement(Rpc it, IHighlightedPositionAcceptor acceptor) {
		return doHighlightNodeForFeature(acceptor, SCHEMA_NODE__NAME, Styles.INTERFACE_STATEMENT_STYLE);
	}

	protected dispatch def boolean doHighlightElement(Notification it, IHighlightedPositionAcceptor acceptor) {
		return doHighlightNodeForFeature(acceptor, SCHEMA_NODE__NAME, Styles.INTERFACE_STATEMENT_STYLE);
	}

	protected dispatch def boolean doHighlightElement(Action it, IHighlightedPositionAcceptor acceptor) {
		return doHighlightNodeForFeature(acceptor, SCHEMA_NODE__NAME, Styles.INTERFACE_STATEMENT_STYLE);
	}

	/*
	 * 5.
	 * Referenceable statement:
	 * Identify/Feature/Extension/TypeDef are other conceptional definition statement.
	 * They will only be valuable or meaningful when they are referenced from other schema node or interface/operation node.
	 */
	protected dispatch def boolean doHighlightElement(Identity it, IHighlightedPositionAcceptor acceptor) {
		if (referenced) {
			doHighlightNodeForFeature(acceptor, SCHEMA_NODE__NAME, Styles.REFERENCEABLE_STATEMENT_STYLE);
		}
		return false;
	}

	protected dispatch def boolean doHighlightElement(Feature it, IHighlightedPositionAcceptor acceptor) {
		if (referenced) {
			doHighlightNodeForFeature(acceptor, SCHEMA_NODE__NAME, Styles.REFERENCEABLE_STATEMENT_STYLE);
		}
		return false;
	}

	protected dispatch def boolean doHighlightElement(Extension it, IHighlightedPositionAcceptor acceptor) {
		if (referenced) {
			doHighlightNodeForFeature(acceptor, SCHEMA_NODE__NAME, Styles.REFERENCEABLE_STATEMENT_STYLE);
		}
		return false;
	}

	protected dispatch def boolean doHighlightElement(Typedef it, IHighlightedPositionAcceptor acceptor) {
		if (referenced) {
			doHighlightNodeForFeature(acceptor, SCHEMA_NODE__NAME, Styles.REFERENCEABLE_STATEMENT_STYLE);
		}
		return false;
	}

	protected def boolean isReferenced(EObject it) {
		return !collectReferences(eResource).get(EcoreUtil.getURI(it)).nullOrEmpty;
	}

	/*
	 * 6.
	 * Other statement:
	 * Of cause, there are lot’s of other statements. From our experience, currently, ‘key’, ‘default’ could be considered to be highlighted.
	 * Meanwhile 'description' providers most important info for all kinds of nodes, so it is important to make 'description' much readable.
	 */
	protected dispatch def boolean doHighlightElement(Description it, IHighlightedPositionAcceptor acceptor) {
		return doHighlightNodeForFeature(acceptor, DESCRIPTION__DESCRIPTION, Styles.DESCRIPTION_STYLE);
	}

	protected dispatch def boolean doHighlightElement(Default it, IHighlightedPositionAcceptor acceptor) {
		return doHighlightNodeForFeature(acceptor, DEFAULT__DEFAULT_STRING_VALUE, Styles.DEFAULT_STYLE);
	}

	protected dispatch def boolean doHighlightElement(Key it, IHighlightedPositionAcceptor acceptor) {
		return doHighlightNodeForFeature(acceptor, KEY__REFERENCES, Styles.KEY_STYLE);
	}

	// Null-guard
	protected dispatch def boolean doHighlightElement(Void it, IHighlightedPositionAcceptor acceptor) {
		return true;
	}

	protected def boolean doHighlightNodeForFeature(EObject object, IHighlightedPositionAcceptor acceptor,
		EStructuralFeature feature, String styleId) {

		val nodes = NodeModelUtils.findNodesForFeature(object, feature)
		acceptor.acceptNodes(nodes, styleId);
		return false;
	}

	protected def void acceptNode(IHighlightedPositionAcceptor acceptor, INode node, String style, String... rest) {
		if (node !== null) {
			acceptor.addPosition(node.offset, node.length, Lists.asList(style, rest));
		}
	}

	protected def void acceptNodes(IHighlightedPositionAcceptor acceptor, Iterable<INode> nodes, String style,
		String... rest) {

		nodes.forEach[acceptor.acceptNode(it, style, rest)];
	}

	override getAllStyleIds() {
		return ImmutableSet.copyOf(STYLE_MAPPINGS.keySet);
	}

	override toScopes(String styleId) {
		val scopes = STYLE_MAPPINGS.get(styleId);
		Preconditions.checkNotNull(scopes, '''Cannot map style ID '«styleId»' to the corresponding TextMate scopes.''');
		return scopes;
	}

}
