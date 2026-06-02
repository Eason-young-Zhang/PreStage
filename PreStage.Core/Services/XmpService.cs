using System.Xml.Linq;
using PreStage.Core.Models;

namespace PreStage.Core.Services;

public class XmpService
{
    private static readonly XNamespace XapNs = "http://ns.adobe.com/xap/1.0/";
    private static readonly XNamespace DcNs = "http://purl.org/dc/elements/1.1/";
    private static readonly XNamespace RdfNs = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
    private static readonly XNamespace PhotoshopNs = "http://ns.adobe.com/photoshop/1.0/";
    private static readonly XNamespace PreStageNs = "https://local.codex/prestage/1.0/";

    public XmpData Read(string sidecarPath)
    {
        try
        {
            var doc = XDocument.Load(sidecarPath);
            var rdf = doc.Root?.Element(RdfNs + "RDF");
            if (rdf == null) return new XmpData();

            var desc = rdf.Element(RdfNs + "Description");
            if (desc == null) return new XmpData();

            var data = new XmpData();
            data.RawDocument = doc;

            foreach (var node in desc.DescendantsAndSelf())
                CollectValues(node, data);

            return data;
        }
        catch
        {
            return new XmpData();
        }
    }

    public void Write(string sidecarPath, XmpData data)
    {
        data = NormalizeForWrite(data);
        XDocument doc;

        if (data.RawDocument != null)
        {
            doc = new XDocument(data.RawDocument);
            var rdf = doc.Root?.Element(RdfNs + "RDF");
            var desc = rdf?.Element(RdfNs + "Description");
            if (desc == null) return;

            ApplyPreStageValues(desc, data);

            if (!string.IsNullOrWhiteSpace(data.CreatorTool))
            {
                SetAttributeIfMissing(desc, XapNs + "CreatorTool", data.CreatorTool);
            }
        }
        else
        {
            doc = CreateNewDocument(data);
        }

        doc.Save(sidecarPath);
    }

    private static XDocument CreateNewDocument(XmpData data)
    {
        XNamespace x = "adobe:ns:meta/";
        var doc = new XDocument(
            new XElement(x + "xmpmeta",
                new XAttribute(XNamespace.Xmlns + "x", x),
                new XElement(RdfNs + "RDF",
                    new XAttribute(XNamespace.Xmlns + "rdf", RdfNs),
                    new XElement(RdfNs + "Description",
                    new XAttribute(RdfNs + "about", ""),
                        new XAttribute(XNamespace.Xmlns + "dc", DcNs),
                        new XAttribute(XNamespace.Xmlns + "xap", XapNs),
                        new XAttribute(XNamespace.Xmlns + "photoshop", PhotoshopNs),
                        new XAttribute(XNamespace.Xmlns + "prestage", PreStageNs),
                        !string.IsNullOrWhiteSpace(data.CreatorTool)
                            ? new XAttribute(XapNs + "CreatorTool", data.CreatorTool) : null,
                        new XAttribute(XapNs + "Rating", data.Rating),
                        new XAttribute(XapNs + "Label", data.Label ?? ""),
                        new XAttribute(PhotoshopNs + "Urgency", PhotoshopUrgency(data.Label)),
                        new XAttribute(PreStageNs + "PickState", data.PickState.ToString())
                    )
                )
            )
        );
        return doc;
    }

    private static void CollectValues(XElement element, XmpData data)
    {
        foreach (var attribute in element.Attributes())
        {
            ApplyValue(LocalName(attribute.Name), attribute.Value, data);
        }

        if (!element.HasElements && !string.IsNullOrWhiteSpace(element.Value))
        {
            ApplyValue(LocalName(element.Name), element.Value, data);
        }
    }

    private static void ApplyValue(string name, string? value, XmpData data)
    {
        if (string.IsNullOrWhiteSpace(value))
            return;

        switch (name)
        {
            case "Rating":
                if (int.TryParse(value.Trim(), out var rating))
                {
                    if (rating == -1)
                    {
                        data.Rating = 0;
                        data.PickState = PickState.Rejected;
                    }
                    else
                    {
                        data.Rating = rating;
                    }
                }
                break;
            case "Label":
                data.Label = value;
                break;
            case "CreatorTool":
                data.CreatorTool = value;
                break;
            case "format":
                data.Format = value;
                break;
            case "PickState":
                if (Enum.TryParse<PickState>(value, ignoreCase: true, out var pickState))
                {
                    if (data.PickState == PickState.Rejected && pickState == PickState.Unmarked)
                        break;

                    data.PickState = pickState;
                }
                break;
        }
    }

    private static XmpData NormalizeForWrite(XmpData data)
    {
        if (data.Rating != -1)
            return data;

        return new XmpData
        {
            Rating = 0,
            Label = data.Label,
            CreatorTool = data.CreatorTool,
            Format = data.Format,
            PickState = PickState.Rejected,
            RawDocument = data.RawDocument
        };
    }

    private static void ApplyPreStageValues(XElement desc, XmpData data)
    {
        EnsureNamespace(desc, "xap", XapNs);
        EnsureNamespace(desc, "photoshop", PhotoshopNs);
        EnsureNamespace(desc, "prestage", PreStageNs);

        SetAttribute(desc, XapNs + "Rating", data.Rating.ToString());
        SetAttribute(desc, XapNs + "Label", data.Label ?? "");
        SetAttribute(desc, PhotoshopNs + "Urgency", PhotoshopUrgency(data.Label).ToString());
        SetAttribute(desc, PreStageNs + "PickState", data.PickState.ToString());

        RemoveLegacyElement(desc, XapNs + "Rating");
        RemoveLegacyElement(desc, XapNs + "Label");
    }

    private static void EnsureNamespace(XElement element, string prefix, XNamespace ns)
    {
        var attr = XNamespace.Xmlns + prefix;
        if (element.Attribute(attr) == null)
            element.SetAttributeValue(attr, ns.NamespaceName);
    }

    private static void SetAttribute(XElement element, XName name, string value)
    {
        element.SetAttributeValue(name, value);
    }

    private static void SetAttributeIfMissing(XElement element, XName name, string value)
    {
        if (element.Attribute(name) == null)
            element.SetAttributeValue(name, value);
    }

    private static void RemoveLegacyElement(XElement element, XName name)
    {
        element.Element(name)?.Remove();
    }

    private static string LocalName(XName name) => name.LocalName;

    private static int PhotoshopUrgency(string? label)
    {
        return label?.Trim().ToLowerInvariant() switch
        {
            "red" => 1,
            "yellow" => 2,
            "green" => 3,
            "blue" => 4,
            "purple" => 5,
            _ => 0
        };
    }

    public static string GetSidecarPath(string mediaPath)
    {
        var dir = Path.GetDirectoryName(mediaPath) ?? "";
        var name = Path.GetFileNameWithoutExtension(mediaPath);
        return Path.Combine(dir, name + ".xmp");
    }
}

public class XmpData
{
    public int Rating { get; set; }
    public string? Label { get; set; }
    public string? CreatorTool { get; set; }
    public string? Format { get; set; }
    public PickState PickState { get; set; } = PickState.Unmarked;
    public XDocument? RawDocument { get; set; }
}
