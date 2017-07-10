<?xml version="1.0" encoding="ISO-8859-1"?>
<StyledLayerDescriptor xmlns:ogc='http://www.opengis.net/ogc' xmlns:xlink='http://www.w3.org/1999/xlink' version='1.0.0' xmlns:gml='http://www.opengis.net/gml' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation='http://www.opengis.net/sld StyledLayerDescriptor.xsd' xmlns='http://www.opengis.net/sld' >
	<NamedLayer>
		<Name><![CDATA[main.ne_10m_populated_places]]></Name>
		<UserStyle>
			<FeatureTypeStyle>
				<Rule>
					<Name><![CDATA[main.ne_10m_populated_places]]></Name>
					<Title><![CDATA[main.ne_10m_populated_places]]></Title>
					<PointSymbolizer>
						<Graphic>
							<ExternalGraphic>
								<OnlineResource xlink:type="simple" xlink:href="mainne_10m_populated_places.png" ></OnlineResource>
								<Format>image/png</Format>
							</ExternalGraphic>
						</Graphic>
					</PointSymbolizer>
					<TextSymbolizer>
						<Label>
							<ogc:PropertyName><![CDATA[NAME]]></ogc:PropertyName>
						</Label>
						<LabelPlacement>
						<PointPlacement>
                            <Displacement>
                                <DisplacementX>25</DisplacementX>
                                <DisplacementY>0</DisplacementY>
                            </Displacement>
						</PointPlacement>
						</LabelPlacement>
						<Font>
							<CssParameter name="font-family" >Arial</CssParameter>
							<CssParameter name="font-weight" >bold</CssParameter>
							<CssParameter name="font-size" >24</CssParameter>
						</Font>
						<Fill>
							<CssParameter name="fill" >#42b9f4</CssParameter>
						</Fill>
					</TextSymbolizer>
				</Rule>
			</FeatureTypeStyle>
		</UserStyle>
	</NamedLayer>
</StyledLayerDescriptor>
