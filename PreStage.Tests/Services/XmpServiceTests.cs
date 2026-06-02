using System.Xml.Linq;
using PreStage.Core.Models;
using PreStage.Core.Services;
using Xunit;

namespace PreStage.Tests.Services;

public class XmpServiceTests
{
    [Fact]
    public void ReadNonExistent_ReturnsEmpty()
    {
        var service = new XmpService();
        var data = service.Read(@"C:\nonexistent\file.xmp");
        Assert.Equal(0, data.Rating);
        Assert.Null(data.Label);
    }

    [Fact]
    public void WriteAndRead_RoundTrip()
    {
        var service = new XmpService();
        var tmpFile = Path.Combine(Path.GetTempPath(), $"prestage_test_{Guid.NewGuid()}.xmp");

        try
        {
            var writeData = new XmpData
            {
                Rating = 4,
                Label = "Red",
                CreatorTool = "PreStage"
            };

            service.Write(tmpFile, writeData);

            Assert.True(File.Exists(tmpFile));

            var readData = service.Read(tmpFile);
            Assert.Equal(4, readData.Rating);
            Assert.Equal("Red", readData.Label);
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }

    [Fact]
    public void WritePreservesUnknownXml()
    {
        var service = new XmpService();
        var tmpFile = Path.Combine(Path.GetTempPath(), $"prestage_test_{Guid.NewGuid()}.xmp");

        try
        {
            var writeData = new XmpData { Rating = 3, CreatorTool = "Lightroom" };
            service.Write(tmpFile, writeData);

            var readData = service.Read(tmpFile);
            service.Write(tmpFile, new XmpData
            {
                Rating = 5,
                RawDocument = readData.RawDocument
            });

            var final = service.Read(tmpFile);
            Assert.Equal(5, final.Rating);
            Assert.Equal("Lightroom", final.CreatorTool);
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }

    [Fact]
    public void LightroomRejectedRating_TreatedAsRejected()
    {
        var service = new XmpService();
        var tmpFile = Path.Combine(Path.GetTempPath(), $"prestage_test_{Guid.NewGuid()}.xmp");

        try
        {
            service.Write(tmpFile, new XmpData { Rating = -1, CreatorTool = "Lightroom" });

            var read = service.Read(tmpFile);
            Assert.Equal(0, read.Rating);
            Assert.Equal(PickState.Rejected, read.PickState);
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }

    [Fact]
    public void GetSidecarPath_ReturnsCorrect()
    {
        var path = @"C:\Photos\IMG_0001.CR3";
        var sidecar = XmpService.GetSidecarPath(path);
        Assert.Equal(@"C:\Photos\IMG_0001.xmp", sidecar);
    }

    [Fact]
    public void ColorLabel_ParsesCorrectly()
    {
        var names = new[] { "Red", "Yellow", "Green", "Blue", "Purple" };
        foreach (var name in names)
        {
            var service = new XmpService();
            var tmpFile = Path.Combine(Path.GetTempPath(), $"prestage_test_{Guid.NewGuid()}.xmp");
            try
            {
                service.Write(tmpFile, new XmpData { Label = name });
                var read = service.Read(tmpFile);
                Assert.Equal(name, read.Label);
            }
            finally
            {
                if (File.Exists(tmpFile)) File.Delete(tmpFile);
            }
        }
    }

    [Fact]
    public void CaptureOneNamespace_RoundTripPreservesUnknownXmlns()
    {
        var captureOneXmp = @"<?xpacket begin="""" id=""W5M0MpCehiHzreSzNTczkc9d""?>
<x:xmpmeta xmlns:x=""adobe:ns:meta/"">
 <rdf:RDF xmlns:rdf=""http://www.w3.org/1999/02/22-rdf-syntax-ns#"">
  <rdf:Description rdf:about=""""
    xmlns:xap=""http://ns.adobe.com/xap/1.0/""
    xmlns:c1=""http://ns.captureone.com/1.0/"">
   <xap:Rating>3</xap:Rating>
   <xap:Label>Green</xap:Label>
   <c1:ColorTag>2</c1:ColorTag>
  </rdf:Description>
 </rdf:RDF>
</x:xmpmeta>
";
        var service = new XmpService();
        var tmpFile = Path.Combine(Path.GetTempPath(), $"prestage_test_{Guid.NewGuid()}.xmp");

        try
        {
            File.WriteAllText(tmpFile, captureOneXmp);

            var readData = service.Read(tmpFile);
            Assert.Equal(3, readData.Rating);
            Assert.Equal("Green", readData.Label);

            readData.Rating = 5;
            service.Write(tmpFile, readData);

            var final = service.Read(tmpFile);
            Assert.Equal(5, final.Rating);

            var doc = XDocument.Load(tmpFile);
            XNamespace rdfNs = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
            XNamespace c1Ns = "http://ns.captureone.com/1.0/";
            var desc = doc.Root?.Element(rdfNs + "RDF")?.Element(rdfNs + "Description");
            var colorTag = desc?.Element(c1Ns + "ColorTag");
            Assert.NotNull(colorTag);
            Assert.Equal("2", colorTag.Value);
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }

    [Fact]
    public void PickState_RoundTripsWithPreStageNamespace()
    {
        var service = new XmpService();
        var tmpFile = Path.Combine(Path.GetTempPath(), $"prestage_test_{Guid.NewGuid()}.xmp");

        try
        {
            service.Write(tmpFile, new XmpData
            {
                Rating = 2,
                Label = "Yellow",
                PickState = PickState.Picked,
                CreatorTool = "PreStage"
            });

            var read = service.Read(tmpFile);
            Assert.Equal(2, read.Rating);
            Assert.Equal("Yellow", read.Label);
            Assert.Equal(PickState.Picked, read.PickState);
        }
        finally
        {
            if (File.Exists(tmpFile)) File.Delete(tmpFile);
        }
    }
}
